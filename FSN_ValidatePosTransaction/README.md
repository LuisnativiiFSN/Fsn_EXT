# EXTENSION DE CALIDACION DE PV

<h1>INDICE</h1>
    
- CodeUnits
    - [ValidatePOSTransaction](#codeunit-validatepostransaction)
- Versions
    - [1.0.0.24](#version10024)
---
## [CodeUnit] ValidatePOSTransaction
---
### [Procedimientos Locales](#codeunit-validatepostransaction)
---
#### [**BlockEditDeliveryOrder**](#procedimientos-locales)
- Descripcion
    <p>Verifica si es un pedido de call para validar si es editable o no</p>
- Dependencias
    - Ninguna

#### [**Tipologia0**](#procedimientos-locales)
- Descripcion
    <p>verifica si es un producto de "tipologia 0" para bloquear o procesar la transaccion</p>
- Dependencias
    - Ninguna

#### [**ValidateControllledProduct**](#procedimientos-globales)
- Descripcion
    <p>Verifica si es un producto controlado con receta medica</p>
- Dependencias
    - Ninguna
---
### [Procedimientos globales](#codeunit-validatepostransaction)
---
#### [**ValidateCustomer**](#procedimientos-globales)
- Descripcion
    <p>verifica el cliente para el aplicar un tipo de descuento y agregarlo ala linea, tambien sirve para aplicar metodos de pago</p>
- Dependencias
    - Ninguna

#### [**ValidateChangeCustomerORMember**](#procedimientos-globales)
- Descripcion
    <p>Valida si es permitido cambiar de cliente</p>
- Dependencias
    - Ninguna

#### [**ValidateItemPendingScann**](#procedimientos-globales)
- Descripcion
    <p>Valida los items que vienen pendientes de escaneo y les cambia el estado</p>
- Dependencias
    - [LinePendingConfirmScannExists](#linependingconfirmscannexists)

#### [**LinePendingConfirmScannExists**](#procedimientos-globales)
- Descripcion
    <p>Recorre las lineas para buscar los items pendientes de escaneo</p>
- Dependencias
    - Ninguna

#### [**CheckTenderReturnSale**](#procedimientos-globales)
- Descripcion
    <p>muestra mensaje indicando como se efectuo la venta orignal</p>
- Dependencias
    - Ninguna

#### [**IsClosedTransExist**](#procedimientos-globales)
- Descripcion
    <p>Valida si se encuentran transaciones marcadas con Z</p>
- Dependencias
    - Ninguna

#### [**ValidateTenderTypeAmount**](#procedimientos-globales)
- Descripcion
    <p>Valida el monto de ese tipo de pago</p>
- Dependencias
    - Ninguna

#### [**ValidateSaleIsReturnSale**](#procedimientos-globales)
- Descripcion
    <p>valida cuando es devolucion Giftcard</p>
- Dependencias
    - Ninguna

---
### [subscripciones](#codeunit-validatepostransaction)
---
#### [**OnAfterTenderKeyPressedEx**](#subscripciones)
- Descripcion
    <p>subscripcion despues de seleccionae metodo de pago</p>
- Dependencias
    - [ValidateTenderTypeAmount](#validatetendertypeamount)
    - [ValidateCustomer](#ValidateCustomer)

#### [**OnAfterValidateCustomerTender**](#subscripciones)
- Descripcion
    <p>subscripcion despues de validar los datos del cliente</p>
- Dependencias
    - [ValidateChangeCustomerORMember](#ValidateChangeCustomerORMember)

#### [**OnBeforeRunPos**](#subscripciones)
- Descripcion
    <p>subscripcion antes de cargar la interfaz del punto de venta</p>
- Dependencias
    - [IsClosedTransExist](#IsClosedTransExist)

#### [**OnBeforeExecuteCommand**](#subscripciones)
- Descripcion
    <p>subscripcion antes de ejecutar un comando de PV</p>
- Dependencias
    - Ninguna

#### [**OnBeforeTotalExecuted**](#subscripciones)
- Descripcion
    <p>subscripcion antes de ejecutar el total del recibo</p>
- Dependencias
    - [LinePendingConfirmScannExists](#LinePendingConfirmScannExists)
    - [Tipologia0](#Tipologia0)
    - [ValidateSaleIsReturnSale](#ValidateSaleIsReturnSale)

#### [**SaveCustomerInfo_OnBeforeModify**](#subscripciones)
- Descripcion
    <p>subscripcion antes de modificar la informacion de un cliente</p>
- Dependencias
    - Ninguna

#### [**OnBeforeCreateLinesToRefund**](#subscripciones)
- Descripcion
    <p>subscripcion antes crear lineas de devolucion</p>
- Dependencias
    - Ninguna

#### [**OnItemNoPressed**](#subscripciones)
- Descripcion
    <p>subscripcion al ingresar un producto</p>
- Dependencias
    - [ValidateItemPendingScann](#ValidateItemPendingScann)
    - [BlockEditDeliveryOrder](#BlockEditDeliveryOrder)
    - [ValidateControllledProduct](#ValidateControllledProduct)

#### [**OnAfterPostTransaction**](#subscripciones)
- Descripcion
    <p>subscripcion despues de postear una transaccion</p>
- Dependencias
    - Ninguna

#### [**OnBeforeItemLine**](#subscripciones)
- Descripcion
    <p>subscripcion antes de agregar la linea del item</p>
- Dependencias
    - Ninguna

#### [**OnBeforeSetFunctionModeSalesPressed**](#subscripciones)
- Descripcion
    <p>subscripcion antes de setear las funciones de venta</p>
- Dependencias
    - Ninguna

#### [**OnBeforeInsertEvent || LSC Report Temp Table**](#subscripciones)
- Descripcion
    <p>subscripcion antes de insertar</p>
- Dependencias
    - Ninguna

#### [**OnPOSCommand**](#subscripciones)
- Descripcion
    <p>subscripcion de ejecucion de comandos de POS</p>
- Dependencias
    - [BlockEditDeliveryOrder](#BlockEditDeliveryOrder)

#### [**OnBeforeDataEntryCheckVoucherRemainingAmt**](#subscripciones)
- Descripcion
    <p>subscripcion antes de chequear el voucher de monto restante</p>
- Dependencias
    - [BlockEditDeliveryOrder](#BlockEditDeliveryOrder)

#### [**OnBeforeInsertEvent || LSC Voucher Entries**](#subscripciones)
- Descripcion
    <p>subscripcion antes de insertar</p>
- Dependencias
    - Ninguna

#### [**OnAfterValidateChangePrice**](#subscripciones)
- Descripcion
    <p>subscripcion despues de cambiar el precio</p>
- Dependencias
    - Ninguna

#### [**OnModalPanelResult**](#subscripciones)
- Descripcion
    <p>subscripcion al levantar un modal</p>
- Dependencias
    - Ninguna

#### [**OnBeforeSalesEntryPosTransLineBufferInsert**](#subscripciones)
- Descripcion
    <p>subscripcion antes de hacer una decolucion de cupones</p>
- Dependencias
    - Ninguna

#### [**ItemLineOnAfterItemGet**](#subscripciones)
- Descripcion
    <p>subscripcion despues de recibir el item antes de insertar la linea</p>
- Dependencias
    - Ninguna

#### [**OnAfterCalcTotals**](#subscripciones)
- Descripcion
    <p>subscripcion despues de calcular el total</p>
- Dependencias
    - Ninguna

#### [**OnBeforeClosePOSPanelInLogoffPressed**](#subscripciones)
- Descripcion
    <p>subscripcion antes de cerrar el punto de venta</p>
- Dependencias
    - Ninguna
---
### [nodificaciones temprales](#codeunit-validatepostransaction)
---
#### [**OnAfterInsertEvent || LSC POS Transaction**](#subscripciones)
- Descripcion
    <p>subscripcion despues de insertar</p>
- Dependencias
    - Ninguna

#### [**OnAfterModifyEvent || LSC POS Transaction**](#subscripciones)
- Descripcion
    <p>subscripcion despues de modificar</p>
- Dependencias
    - Ninguna

#### [**OnAfterInsertEvent || LSC POS Trans. Line**](#subscripciones)
- Descripcion
    <p>subscripcion despues de insertar</p>
- Dependencias
    - Ninguna

#### [**OnAfterModifyEvent || LSC POS Trans. Line**](#subscripciones)
- Descripcion
    <p>subscripcion despues de modificar</p>
- Dependencias
    - Ninguna
---
## [Version]1.0.0.24
Se agrega la funcionalidad de poder hacer devoluciones de cupones [OnBeforeSalesEntryPosTransLineBufferInsert](#OnBeforeSalesEntryPosTransLineBufferInsert), se agrego el parche para seleccionar la unidad de medida de un producto al ingresarlo [ItemLineOnAfterItemGet](#ItemLineOnAfterItemGet) y se agrego un parche para cargar la ultima transaccion de no ser totalizada [OnBeforeClosePOSPanelInLogoffPressed](#OnBeforeClosePOSPanelInLogoffPressed)