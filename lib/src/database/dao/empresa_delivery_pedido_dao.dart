/*
Title: T2Ti ERP Pegasus                                                                
Description: DAO relacionado à tabela [EMPRESA_DELIVERY_PEDIDO] 
                                                                                
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

part 'empresa_delivery_pedido_dao.g.dart';

@UseDao(tables: [
  EmpresaDeliveryPedidos,
])
class EmpresaDeliveryPedidoDao extends DatabaseAccessor<AppDatabase>
    with _$EmpresaDeliveryPedidoDaoMixin {
  final AppDatabase db;

  EmpresaDeliveryPedidoDao(this.db) : super(db);

  Future<List<EmpresaDeliveryPedido>?> consultarLista() =>
      select(empresaDeliveryPedidos).get();

  Future<List<EmpresaDeliveryPedido>?> consultarListaFiltro(
      String campo, String valor) async {
    return (customSelect(
        "SELECT * FROM EMPRESA_DELIVERY_PEDIDO WHERE " +
            campo +
            " like '%" +
            valor +
            "%'",
        readsFrom: {empresaDeliveryPedidos}).map((row) {
      return EmpresaDeliveryPedido.fromData(row.data, db);
    }).get());
  }

  Future<EmpresaDeliveryPedido?> consultarObjetoFiltro(
      String campo, String valor) async {
    return (customSelect(
        "SELECT * FROM EMPRESA_DELIVERY_PEDIDO WHERE " +
            campo +
            " = '" +
            valor +
            "'",
        readsFrom: {empresaDeliveryPedidos}).map((row) {
      return EmpresaDeliveryPedido.fromData(row.data, db);
    }).getSingleOrNull());
  }

  Stream<List<EmpresaDeliveryPedido>> observarLista() =>
      select(empresaDeliveryPedidos).watch();

  Future<EmpresaDeliveryPedido?> consultarObjeto(int pId) {
    return (select(empresaDeliveryPedidos)..where((t) => t.id.equals(pId)))
        .getSingleOrNull();
  }

  Future<int> inserir(Insertable<EmpresaDeliveryPedido> pObjeto) {
    return transaction(() async {
      final idInserido = await into(empresaDeliveryPedidos).insert(pObjeto);
      return idInserido;
    });
  }

  Future<bool> alterar(Insertable<EmpresaDeliveryPedido> pObjeto) {
    return transaction(() async {
      return update(empresaDeliveryPedidos).replace(pObjeto);
    });
  }

  Future<int> excluir(Insertable<EmpresaDeliveryPedido> pObjeto) {
    return transaction(() async {
      return delete(empresaDeliveryPedidos).delete(pObjeto);
    });
  }
}
