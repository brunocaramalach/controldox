/*
Title: T2Ti ERP 3.0
Description: Service utilizado para consumir o ACBrMonitor diretamente
                                                                                
The MIT License                                                                 
                                                                                
Copyright: Copyright (C) 2021 T2Ti.COM                                          
                                                                                
Permission is hereby granted, free of charge, to any person                     
obtaining a copy of this software and associated documentation                  
files (the "Software"), to deal in the Software without                         
restriction, including without limitation the rights to use,                    
copy, modify, merge, publish, distribute, sublicense, and/or sell               
copies of the Software, and to permit persons to whom the                       
Software is furnished to do so, subject to the following                        
conditions:                                                                     
                                                                                
The above copyright notice and this permission notice shall be                  
included in all copies or substantial portions of the Software.                 
                                                                                
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,                 
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES                 
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND                        
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT                     
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,                    
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING                    
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR                   
OTHER DEALINGS IN THE SOFTWARE.                                                 
                                                                                
       The author may be contacted at:                                          
           t2ti.com@gmail.com                                                   
                                                                                
@author Albert Eije (alberteije@gmail.com)                    
@version 1.0.0
*******************************************************************************/
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:charcode/ascii.dart';

import 'package:controldox/src/infra/infra.dart';
import 'package:controldox/src/view/shared/caixas_de_dialogo.dart';
import 'package:controldox/src/controller/controller.dart';

/// classe respons??vel por requisi????es ao ACBrMonitor diretamente
class NfceAcbrService {
  BuildContext? _context;
  Socket? _socket;
  Function? _funcaoDeCallBack;
  String? _chaveAcesso;
  /*
    ====================================================================================================================
    poss??veis valores para a vari??vel _operacao:
    ====================================================================================================================
    CRIAR - comando para criar o XML inicial da nota fiscal, ser?? assinado por padr??o
    ENVIAR - comando para enviar o XML criado para a sefaz
    CANCELAR - comando enviado para cancelar uma nota fiscal
    IMPRIMIR DANFE - comando enviado para imprimir o danfe
    DOWNLOAD_DANFE - comando enviado para baixar o arquivo PDF em base64
    CONTINGENCIA - o sistema entrou em modo de conting??ncia
    TRANSMITIR_CONTINGENCIADA - transmite as notas que est??o com status=6
    INUTILIZAR_NUMERO - inutilizar o n??mero ou o intervalo de n??meros da nfc-e
  */
  String? _operacao;
  String? _formaEmissao; //1=normal | 9=conting??ncia off-line
  late String
      _caminhoXmlCriado; //caminho do XML inicial criado - xml ainda n??o foi enviado para a sefaz - aqui pegamos tamb??m a chave de acesso criada pelo monitor
  String?
      _motivoCancelamento; // motivo enviado pela tela de cancelamento - ser?? persistido na base de dados e enviado para a sefaz
  late String _respostaServidor; // armazena a resposta enviada pelo ACBrMonitor
  late bool
      _contemEndOfText; // verifica se a resposta do servidor cont??m o caractere de final de linha
  late bool
      _rejeicaoServidorFora; // controla se o servidor da sefaz est?? fora do ar: rejei????es 109 e 999

  bool _aguardaFimRetornoPDF =
      false; // em alguns momentos no Android o PDF (string base64) n??o ?? 'recebido' completo - vamos testar essa condi????o e concatenar o retorno

  final enderecoServidor =
      InternetAddress(Sessao.configuracaoPdv!.acbrMonitorEndereco!);
  final portaServidor = Sessao.configuracaoPdv!.acbrMonitorPorta;

  Future<Socket?> conectar(BuildContext context,
      {Function? funcaoDeCallBack,
      String? chaveAcesso,
      String? operacao,
      String? formaEmissao,
      String? motivoCancelamento}) async {
    _formaEmissao = formaEmissao;
    _context = context;
    _funcaoDeCallBack = funcaoDeCallBack;
    _chaveAcesso = chaveAcesso;
    _operacao = operacao;
    _motivoCancelamento = motivoCancelamento;

    await Socket.connect(enderecoServidor, portaServidor!)
        .then((Socket socket) {
      _socket = socket;
      _socket!.listen(
        _tratarRetornoSocket,
        onError: _tratarErro,
        onDone: _onDone,
      );
    });
    return _socket;
  }

  void _tratarRetornoSocket(Uint8List? data) async {
    //_respostaServidor = String.fromCharCodes(data).trim();

    if (_aguardaFimRetornoPDF) {
      if (data != null) {
        _respostaServidor =
            _respostaServidor + String.fromCharCodes(data).trim();
        //log('Resposta Servidor: ' + _respostaServidor);
      }
    } else {
      _respostaServidor = String.fromCharCodes(data!).trim();
    }

    final caractereFinal = _respostaServidor.substring(
        _respostaServidor.length - 1, _respostaServidor.length);
    _contemEndOfText = (caractereFinal.codeUnitAt(0) == $etx);
    _rejeicaoServidorFora = false;

    debugPrint('RESPOSTA SERVIDOR = ' + _respostaServidor);

    if (_respostaServidor.contains('Rejeicao')) {
      // REJEI????O - TRATAR
      debugPrint('=== REJEICAO');
      if (_respostaServidor
                  .contains('999') || // Rejei????o 999: Erro n??o catalogado
              _respostaServidor.contains(
                  '109') // Rejei????o 109: Servi??o paralisado sem previs??o
          ) {
        _rejeicaoServidorFora = true;
        _tratarErroRetornado();
      } else {
        _exibirMensagemRejeicao();
      }
    } else if (_respostaServidor.contains('OK:') && _operacao == 'CRIAR') {
      // CRIOU XML - ENVIAR NOTA
      if (_respostaServidor.contains('Alertas')) {
        debugPrint(
            '=== XML CRIADO - MAS DESCEU UM ALERTA - MOSTRAR PARA O USUARIO');
        _exibirAlerta();
      } else {
        debugPrint('=== XML CRIADO - COMANDO PARA ENVIAR NOTA');
        _enviarNota();
      }
    } else if (_respostaServidor.contains('OK:') && _operacao == 'RECRIAR') {
      // RECRIOU XML - ENVIAR NOTA EM CONTINGENCIA
      debugPrint(
          '=== XML RECRIADO - COMANDO PARA IMPRIMIR O DANFE EM CONTINGENCIA');
      await _imprimirDanfeEmContingencia();
    } else if (_respostaServidor.contains('OK:') && _operacao == 'INICIO') {
      // INICIO DOS PROCEDIMENTOS - MANDA CRIAR O XML
      debugPrint('=== EMISS??O NORMAL - VAMOS CRIAR O XML INICIAL DA NOTA');
      _criarNota();
    } else if (_respostaServidor.contains('OK:') &&
        _operacao == 'INUTILIZAR_NUMERO') {
      // INUTILIZA????O DO N??MERO DEU CERTO NO SERVIDOR - VAMOS CHAMAR O M??TODO DE CALLBACK
      debugPrint(
          '=== INUTILIZA????O DO N??MERO DEU CERTO NO SERVIDOR - VAMOS CHAMAR O M??TODO DE CALLBACK');
      _chamarCallbackInutilizarNumero();
    } else if (_respostaServidor.contains('OK:') &&
        _operacao == 'CONTINGENCIA') {
      // ENTROU EM CONTINGENCIA - MANDA RECRIAR O XML
      debugPrint('=== ENTROU EM CONTINGENCIA - RECRIAR O XML');
      _recriarNotaContingencia();
    } else if (_respostaServidor.contains('cStat=100')) {
      // cStat=100: nota autorizada - IMPRIMIR DANFE
      debugPrint('=== NOTA FOI AUTORIZADA - COMANDO PARA ENVIAR DANFE ENVIADO');
      await _imprimirDanfeNormal();
    } else if (_respostaServidor.contains('ERRO')) {
      // SERVIDOR RETORNOU ERRO - TRATAR
      debugPrint('=== DEU ERRO');
      await _tratarErroRetornado();
    } else if (_respostaServidor.contains('-nfe.pdf')) {
      // ARQUIVO PDF FOI CRIADO - BAIXAR ARQUIVO EM BASE64
      debugPrint(
          '=== RESPOSTA DO SERVIDOR INDICA QUE O ARQUIVO DO DANFE FOI CRIADO - COMANDO PARA BAIXAR O ARQUIVO ENVIADO');
      _fazerDownloadPdfDanfe();
    } else if (_respostaServidor.contains('OK') &&
        _respostaServidor.contains('Cancelamento')) {
      // NOTA FOI CANCELADA - ATUALIZAR DADOS LOCAIS
      debugPrint(
          '=== VOLTOU O RETORNO DO CANCELAMENTO - CANCELAR A NOTA LOCALMENTE');
      await _tratarRetornoCancelamento();
    } else if (_respostaServidor.length > 10000) {
      // RETORNOU ARQUIVO PDF DO SERVIDOR - MOSTRAR NA TELA
      debugPrint('=== DESCEU O PDF - EXIBIR NA TELA');
      //_exibirDanfeNaTela();
      if (_contemEndOfText) {
        _aguardaFimRetornoPDF = false;
        _exibirDanfeNaTela();
      } else {
        _aguardaFimRetornoPDF = true;
      }
    } else if (_respostaServidor.codeUnitAt(0) == $etx) {
      // VOLTOU APENAS O CARACTERE DE FINAL DE LINHA
      debugPrint('=== VOLTOU APENAS O CARACTERE DE FINAL DE LINHA');
    } else {
      // IN??CIO DO PROCEDIMENTO - ABRE JANELA DE ESPERA
      debugPrint('=== MOSTRA A JANELA DE ESPERA');
      if (!Sessao.abriuDialogBoxEspera) {
        Sessao.abriuDialogBoxEspera = true;
        gerarDialogBoxEspera(_context!);
      }
    }
  }

  void _exibirMensagemRejeicao() {
    Sessao.abriuDialogBoxEspera = false;
    String? motivoRejeicao;
    if (_contemEndOfText) {
      motivoRejeicao = NfceController.retornarMotivoRejeicao(
          _respostaServidor.substring(0, _respostaServidor.length - 1));
    } else {
      motivoRejeicao = NfceController.retornarMotivoRejeicao(_respostaServidor);
    }
    Sessao.fecharDialogBoxEspera(_context!);
    gerarDialogBoxErro(
        _context,
        'Ocorreu um problema ao tentar realizar o procedimento: ' +
            motivoRejeicao!);
  }

  void _criarNota() {
    _operacao = 'CRIAR';
    _socket!
        .write('NFe.CriarNFe("' + Sessao.ultimoIniNfceEnviado + '")\r\n.\r\n');
  }

  void _recriarNotaContingencia() {
    _operacao = 'RECRIAR';
    _socket!
        .write('NFe.CriarNFe("' + Sessao.ultimoIniNfceEnviado + '")\r\n.\r\n');
  }

  void _enviarNota() {
    _pegarDadosXml();
    _operacao = 'ENVIAR';
    _socket!.write('NFe.EnviarNFe("' +
        _caminhoXmlCriado +
        '", "001", , , , "1", , )\r\n.\r\n');
  }

  void _pegarDadosXml() {
    if (_contemEndOfText) {
      _caminhoXmlCriado =
          _respostaServidor.substring(4, _respostaServidor.length - 1);
    } else {
      _caminhoXmlCriado = _respostaServidor.substring(4);
    }
    _chaveAcesso = NfceController.retornarChaveDoCaminhoXml(_caminhoXmlCriado);
  }

  Future _imprimirDanfeEmContingencia() async {
    _pegarDadosXml();
    _socket!.write(
        'NFE.ImprimirDANFEPDF("' + _caminhoXmlCriado + '", , , , ,")\r\n.\r\n');
    _operacao = 'IMPRIMIR_DANFE';
    await NfceController.atualizarDadosNfce(
        chaveAcesso: _chaveAcesso, statusNota: '6'); // 6=contingencia
  }

  Future _imprimirDanfeNormal() async {
    if (_contemEndOfText) {
      _chaveAcesso = NfceController.retornarChaveDoIni(
          _respostaServidor.substring(0, _respostaServidor.length - 1));
    } else {
      _chaveAcesso = NfceController.retornarChaveDoIni(_respostaServidor);
    }
    await NfceController.atualizarDadosNfce(
        chaveAcesso: _chaveAcesso, statusNota: '4'); // autorizada
    _operacao = 'IMPRIMIR_DANFE';
    _socket!.write('NFE.ImprimirDANFEPDF("' +
        Sessao.configuracaoNfce!.caminhoSalvarXml! +
        Biblioteca.formatarDataAAAAMM(DateTime.now()) +
        '\\NFCe\\' +
        _chaveAcesso! +
        '-nfe.xml")\r\n.\r\n');
  }

  void _fazerDownloadPdfDanfe() {
    _operacao = 'DOWNLOAD_DANFE';
    _socket!.write('ACBr.EncodeBase64("' +
        Sessao.configuracaoNfce!.caminhoSalvarPdf! +
        Biblioteca.formatarDataAAAAMM(DateTime.now()) +
        '\\NFCe\\' +
        _chaveAcesso! +
        '-nfe.pdf")\r\n.\r\n');
  }

  Future _tratarRetornoCancelamento() async {
    await NfceController.atualizarDadosNfce(
        chaveAcesso: _chaveAcesso,
        statusNota: '5',
        motivoCancelamento: _motivoCancelamento); // cancelada
    await _funcaoDeCallBack!();
    Sessao.abriuDialogBoxEspera = false;
    Sessao.fecharDialogBoxEspera(_context!);
  }

  void _exibirDanfeNaTela() {
    Sessao.abriuDialogBoxEspera = false;
    Sessao.fecharDialogBoxEspera(_context!);
    if (_contemEndOfText) {
      _funcaoDeCallBack!(
          _respostaServidor.substring(4, _respostaServidor.length - 1).trim());
    } else {
      _funcaoDeCallBack!(
          _respostaServidor.substring(4, _respostaServidor.length).trim());
    }
  }

  void _chamarCallbackInutilizarNumero() async {
    Sessao.abriuDialogBoxEspera = false;
    Sessao.fecharDialogBoxEspera(_context!);
    await _funcaoDeCallBack!();
  }

  void _exibirAlerta() {
    Sessao.abriuDialogBoxEspera = false;
    Sessao.fecharDialogBoxEspera(_context!);
    gerarDialogBoxErro(
        _context,
        'Ocorreu um problema ao tentar realizar o procedimento: ' +
            _respostaServidor);
  }

  Future _tratarErroRetornado() async {
    // se a forma de emiss??o for 9, ent??o j?? enviamos o comando para ENVIAR em conting??ncia e ainda assim ocorreu um ERRO, qua vamos apenas mostrar na tela para o usu??rio
    if (_formaEmissao == '9') {
      Sessao.fecharDialogBoxEspera(_context!);
      Sessao.abriuDialogBoxEspera = false;
      gerarDialogBoxErro(
          _context,
          'Ocorreu um problema ao tentar realizar o procedimento: ' +
              _respostaServidor);
    } else {
      if (_respostaServidor.contains(
                  '12002') || // TimeOut de Requisi????o - problemas com o servidor da sefaz
              _rejeicaoServidorFora // Rejei????o 109 ou 999
          ) {
        if (_operacao == 'CANCELAR' ||
            _operacao == 'TRANSMITIR_CONTINGENCIADA') {
          Sessao.fecharDialogBoxEspera(_context!);
          Sessao.abriuDialogBoxEspera = false;
          gerarDialogBoxErro(_context,
              'Ocorreu um problema ao tentar realizar o procedimento: Servidor da SEFAZ est?? fora.');
        } else {
          if (NfceController.ufPermiteContingenciaOffLine(Sessao.empresa!.uf)) {
            debugPrint('=== PASSANDO O MODO DE EMISSAO PARA CONTINGENCIA');
            gerarDialogBoxConfirmacao(
                _context,
                'Deseja IMPRIMIR a nota em conting??ncia? OBS: Imprima o DANFE em DUAS VIAS (uma para o consumidor e outra '
                'para ficar a disposi????o do Fisco no estabelecimento).',
                () async {
              if (await NfceController.gerarDadosNfceContingencia(
                  _chaveAcesso)) {
                _socket!
                    .write('NFE.SetFormaEmissao(9)")\r\n.\r\n'); // 9=offline
                _formaEmissao = '9';
                _operacao = 'CONTINGENCIA';
              }
            }, onCancelPressed: () {
              Sessao.fecharDialogBoxEspera(_context!);
              Sessao.abriuDialogBoxEspera = false;
            });
          } else {
            Sessao.fecharDialogBoxEspera(_context!);
            Sessao.abriuDialogBoxEspera = false;
            gerarDialogBoxErro(_context,
                'Ocorreu um problema ao tentar realizar o procedimento: Servidor da SEFAZ est?? fora.');
          }
        }
      } else {
        // aconteceu algum outro tipo de erro
        Sessao.fecharDialogBoxEspera(_context!);
        Sessao.abriuDialogBoxEspera = false;
        gerarDialogBoxErro(
            _context,
            'Ocorreu um problema ao tentar realizar o procedimento: ' +
                _respostaServidor);
      }
    }
  }

  void _tratarErro(error, StackTrace trace) {
    debugPrint(error);
  }

  void _onDone() {
    _socket!.destroy();
  }
}

/* LISTA DE COMANDOS DO ACBRMONITOR UTILIZADOS
  // https://acbr.sourceforge.io/ACBrMonitor/NFEEnviarNFe.html
  // https://acbr.sourceforge.io/ACBrMonitor/NFEImprimirDANFEPDF.html
  // https://acbr.sourceforge.io/ACBrMonitor/ACBrEncodeBase64.html
  // https://acbr.sourceforge.io/ACBrMonitor/NFESetFormaEmissao.html
  // https://acbr.sourceforge.io/ACBrMonitor/NFECancelarNFe.html
  // https://acbr.sourceforge.io/ACBrMonitor/NFECriarNFe.html
  // https://acbr.sourceforge.io/ACBrMonitor/ModeloNFeINICompleto.html
*/
