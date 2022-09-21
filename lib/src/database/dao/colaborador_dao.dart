/*
Title: T2Ti ERP Pegasus                                                                
Description: DAO relacionado à tabela [COLABORADOR] 
                                                                                
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
import 'package:moor/moor.dart';

import 'package:controldox/src/database/database.dart';
import 'package:controldox/src/database/database_classes.dart';

part 'colaborador_dao.g.dart';

@UseDao(tables: [
  Colaboradors,
])
class ColaboradorDao extends DatabaseAccessor<AppDatabase>
    with _$ColaboradorDaoMixin {
  final AppDatabase db;

  List<Colaborador>?
      listaColaborador; // será usada para popular a grid na janela do colaborador

  ColaboradorDao(this.db) : super(db);

  Future<List<Colaborador>?> consultarLista() async {
    listaColaborador = await select(colaboradors).get();
    aplicarDomains();
    return listaColaborador;
  }

  Future<List<Colaborador>?> consultarListaFiltro(
      String campo, String valor) async {
    listaColaborador = await (customSelect(
        "SELECT * FROM COLABORADOR WHERE " + campo + " like '%" + valor + "%'",
        readsFrom: {colaboradors}).map((row) {
      return Colaborador.fromData(row.data, db);
    }).get());
    aplicarDomains();
    return listaColaborador;
  }

  Stream<List<Colaborador>> observarLista() => select(colaboradors).watch();

  Future<Colaborador?> consultarObjeto(int pId) {
    return (select(colaboradors)..where((t) => t.id.equals(pId)))
        .getSingleOrNull();
  }

  Future<int> inserir(Insertable<Colaborador> pObjeto) {
    return transaction(() async {
      final colaborador = removerDomains(pObjeto as Colaborador);
      final idInserido = await into(colaboradors).insert(colaborador);
      return idInserido;
    });
  }

  Future<bool> alterar(Insertable<Colaborador> pObjeto) {
    return transaction(() async {
      final colaborador = removerDomains(pObjeto as Colaborador);
      return update(colaboradors).replace(colaborador);
    });
  }

  Future<int> excluir(Insertable<Colaborador> pObjeto) {
    return transaction(() async {
      return delete(colaboradors).delete(pObjeto);
    });
  }

  Colaborador removerDomains(Colaborador colaborador) {
    if (colaborador.entregadorVeiculo != null) {
      colaborador = colaborador.copyWith(
          entregadorVeiculo: colaborador.entregadorVeiculo!.substring(0, 1));
    }
    return colaborador;
  }

  void aplicarDomains() {
    for (var i = 0; i < listaColaborador!.length; i++) {
      switch (listaColaborador![i].entregadorVeiculo) {
        case 'C':
          listaColaborador![i] = listaColaborador![i].copyWith(
            entregadorVeiculo: 'Carro',
          );
          break;
        case 'M':
          listaColaborador![i] = listaColaborador![i].copyWith(
            entregadorVeiculo: 'Moto',
          );
          break;
        case 'B':
          listaColaborador![i] = listaColaborador![i].copyWith(
            entregadorVeiculo: 'Bicicleta',
          );
          break;
        case 'A':
          listaColaborador![i] = listaColaborador![i].copyWith(
            entregadorVeiculo: 'Aplicativo',
          );
          break;
        default:
      }
    }
  }

  static List<String> campos = <String>[
    'ID',
    'NOME',
    'CPF',
    'TELEFONE',
    'CELULAR',
    'EMAIL',
    'COMISSAO_VISTA',
    'COMISSAO_PRAZO',
  ];

  static List<String> colunas = <String>[
    'Id',
    'Nome',
    'Cpf',
    'Telefone',
    'Celular',
    'Email',
    'Comissao Vista',
    'Comissao Prazo',
  ];
}
