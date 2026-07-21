# EXTENSION DE RELLENADO

<h1>INDICE</h1>

- CodeUnits
    - [FSNReplenCalculation](#codeunits-fsnreplencalculation)
- Pages
    - [BackupTransferTemplate](#page-backuptranefertemplate)
    - [FSN_StockRequest](#page-fsn_stockrequest)
    - [ReplenPurchMatrix](#page-replenpurchmatrix)
    - [ReplenPurchMatrixDetail](#page-replenpurchmatrixdetail)
- Pages Extension
    - [PurchaseReplenishJournalExt](#pageext-purchasereplenishjournalext)
    - [PurchReplenJrnlDetailsExt](#pageext-purchreplenjrnldetailsext)
    - [ReplenItemStoreRecExt](#pageext-replenitemstorerecext)
    - [ReplenSetupExt](#pageext-replensetupext)
    - [ReplenTemplateCardExt](#pageext-replentemplatecardext)
    - [RetailPurchOrderListExt](#pageext-retailpurchorderlistext)
    - [RetailTransferOrderListExt](#pageext-retailtransferorderlistext)
    - [StockRequestExt](#pageext-stockrequestext)
    - [TransferReplenishJournalExt](#pageext-transferreplenishjournalext)
    - [TransferReplenJrnDetailExt](#pageext-transferreplenjrndetailext)
- Querys
    - [GetPurchasePerVendor](#query-getpurchasepervendor)
- Reports
    - [ReplenAutomaticRunFSN](#reports-replenautomaticrunfsn)
    - [ReplenishmentQtyByLocation](#reports-replenishmentqtybylocation)
- Tables
    - [ReplenTemplateMatrix](#tables-replentemplatematrix)
    - [LevelUpdate](#tables-levelupdate)
- Tables Extension
    - [ReplenSetupExt](#tablesext-replensetupext)
    - [ReplenTemplateExt](#tablesext-replentemplateext)
- Versions
    - [1.0.0.10](#version-10010)
    - [1.0.0.11](#version-10011)
    - [1.0.0.12](#version-10012)
---
## [CodeUnits] FSNReplenCalculation
---
### [Procedimientos locales](#codeunits-fsnreplencalculation)
---
#### [**VerifyReplenRecDescriptions**](#procedimientos-locales)
- Descripcion
    <p>Modifica datos del replen Item Store con los datos del REC</p>
- Dependencias
    - Ninguna
#### [**SetStaticMultipleLess**](#procedimientos-locales)
- Descripcion
    <p>Establece el valor de la variable StaticMultipleLess</p>
- Dependencias
    - Ninguna
---
### [Procedimientos globales](#codeunits-fsnreplencalculation)
---
#### [**ReplenTemplatePurchases**](#procedimientos-globales)
- Descripcion
    <p>Ejecuta el reporte de compras para cada item de la plantilla de reabastecimiento</p>
- Dependencias
    - Ninguna
#### [**ReplenTemplateTransfers**](#procedimientos-globales)
- Descripcion
    <p>Ejecuta el reporte de transferencias para cada item de la plantilla de reabastecimiento</p>
- Dependencias
    - Ninguna
#### [**VerifyMultipleReplenRecConsistency**](#procedimientos-globales)
- Descripcion
    <p>Verifica la consistencia de multiplicar reabastecimiento</p>
- Dependencias
    - Ninguna
#### [**FSNInicializeReplenRec**](#procedimientos-globales)
- Descripcion
    <p>Inicializa los datos del replen Item Store con los datos del REC</p>
- Dependencias
    - Ninguna
#### [**ProcessApproachPurchMult**](#procedimientos-globales)
- Descripcion
    <p>Procesa el reabastecimiento de compras con multiplicador</p>
- Dependencias
    - [SetStaticMultipleLess](#SetStaticMultipleLess)
---
### [Subcripciones](#codeunits-fsnreplencalculation)
---
#### [**OnBeforeModifyEvent**](#subcripciones)
- Descripcion
    <p>Evento antes de modificar el registro</p>
- Dependencias
    - [VerifyMultipleReplenRecConsistency](#VerifyMultipleReplenRecConsistency)
#### [**OnBeforeInsertEvent**](#subcripciones)
- Descripcion
    <p>Evento antes de insertar el registro</p>
- Dependencias
    - [FSNInicializeReplenRec](#FSNInicializeReplenRec)
#### [**OnAfterModifyEvent**](#subcripciones)
- Descripcion
    <p>Evento despues de modificar el registro</p>
- Dependencias
    - [VerifyReplenRecDescriptions](#VerifyReplenRecDescriptions)
#### [**OnBeforeActionEvent**](#subcripciones)
- Descripcion
    <p>Evento antes de ejecutar la accion</p>
- Dependencias
    - Ninguna
#### [**OnBeforeInsertEvent**](#subcripciones)
- Descripcion
    <p>Evento antes de insertar el registro</p>
- Dependencias
    - Ninguna
#### [**OnBeforeValidateEvent**](#subcripciones)
- Descripcion
    <p>Evento antes de validar el registro</p>
- Dependencias
    - Ninguna
#### [**OnInsertWorksheetLineOnBeforeSetReplenJournalLinesPar**](#subcripciones)
- Descripcion
    <p>Evento antes de insertar la linea de la hoja de trabajo</p>
- Dependencias
    - Ninguna
#### [**OnInsertWorksheetDetailOnBeforeInsertReplenJrnlDetails**](#subcripciones)
- Descripcion
    <p>Evento antes de insertar el detalle de la hoja de trabajo</p>
- Dependencias
    - [ProcessApproachPurchMult](#ProcessApproachPurchMult)
#### [**OnInsertRedistWorksheetDetailOnBeforeInsertReplenJrnlDetails**](#subcripciones)
- Descripcion
    <p>Evento antes de insertar el detalle de la hoja de trabajo</p>
- Dependencias
    - Ninguna
#### [**OnBeforeActionEvent|Create &Transfer Orders**](#subcripciones)
- Descripcion
    <p>Evento antes de ejecutar la accion</p>
- Dependencias
    - Ninguna
#### [**OnAfterActionEvent|Add Items to Journal**](#subcripciones)
- Descripcion
    <p>Evento despues de ejecutar la accion</p>
- Dependencias
    - Ninguna
---
## [Page] BackupTraneferTemplate
---
### [Tabla](#page-backuptranefertemplate)
---
#### **FSN BackOrder Transfer Line**
---
### [Acciones](#page-backuptranefertemplate)
---
##### **Ninguna**
---
### [Procedimientos](#page-backuptranefertemplate)
---
##### **Ninguno**
---
## [Page] FSN_StockRequest
---
### [Tabla](#page-fsn_stockrequest)
---
#### **LSC InStore Stock Req. Header**
---
### [Acciones](#page-fsn_stockrequest)
---
#### [**"&Reference Document"**](#acciones-1)
- Descripcion
    <p>Abre la pagina de referencia del documento</p>
- Dependencias
    - Ninguna
#### [**"&Send Request"**](#acciones-1)
- Descripcion
    <p>Envia la solicitud de stock</p>
- Dependencias
    - Ninguna
#### [**"&Decline Request"**](#acciones-1)
- Descripcion
    <p>Rechaza la solicitud de stock</p>
- Dependencias
    - Ninguna
#### [**"&Assign Request"**](#acciones-1)
- Descripcion
    <p>Asigna la solicitud de stock</p>
- Dependencias
    - [ValidateNotRepeatProducts](#ValidateNotRepeatProducts)

#### [**"&Validate Inventory"**](#acciones-1)
- Descripcion
    <p>Valida el stock en otra tabla de inventario</p>
- Dependencias
    - [ValidateInventory](#ValidateInventory)
---
### [Procedimientos](#page-fsn_stockrequest)
---
#### [**UpdateForm**](#procedimientos-1)
- Descripcion
    <p>Actualiza el formulario Segun el uso a darle</p>
- Dependencias
    - Ninguna
#### [**PurchaseOrderDocumentTypeOnVal**](#procedimientos-1)
- Descripcion
    <p>Valida el tipo de documento de compra, y actualiza la pagina</p>
- Dependencias
    - [UpdateForm](#updateform)
#### [**TransferOrderDocumentTypeOnVal**](#procedimientos-1)
- Descripcion
    <p>Valida el tipo de documento de transferencia, y actualiza la pagina</p>
- Dependencias
    - [UpdateForm](#updateform)
#### [**CreateProcessTypeOnValidate**](#procedimientos-1)
- Descripcion
    <p>Valida el tipo de proceso, y actualiza la pagina</p>
- Dependencias
    - [UpdateForm](#updateform)
#### [**ReplenishProcessTypeOnValidate**](#procedimientos-1)
- Descripcion
    <p>Valida el tipo de proceso, y actualiza la pagina</p>
- Dependencias
    - [UpdateForm](#updateform)

#### [**ValidateInventory**](#procedimientos-1)
- Descripcion
    <p>consulta la tabla de nivel de inventario para validar la solicitud de stock </p>
- Dependencias
    - [ValidateNotRepeatProducts](#ValidateNotRepeatProducts)

#### [**ValidateNotRepeatProducts**](#procedimientos-1)
- Descripcion
    <p>Valida que no se repitan los productos en la solicitud de stock</p>
- Dependencias
    - Ninguna
---
## [Page] ReplenPurchMatrix
---
### [Tabla](#page-replenpurchmatrix)
---
#### **LSC Replen. Journal Lines**
---
### [Acciones](#page-replenpurchmatrix)
---
#### [**"Previous Set"**](#acciones-2)
- Descripcion
    <p>carga la pagina con la matriz anterior</p>
- Dependencias
    - [SetColumns](#SetColumns)
#### [**"Next Set"**](#acciones-2)
- Descripcion
    <p>carga la pagina con la matriz siguiente</p>
- Dependencias
    - [SetColumns](#SetColumns)
#### [**"Quick Report"**](#acciones-2)
- Descripcion
    <p>Genera el reporte de la matriz</p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#page-replenpurchmatrix)
---
#### [**SetColumns**](#procedimientos-2)
- Descripcion
    <p>Setea las columnas de la pagina</p>
- Dependencias
    - Ninguna
#### [**ShowColumnNameOnAfterValidate**](#procedimientos-2)
- Descripcion
    <p>Valida el nombre de la columna, y actualiza la pagina</p>
- Dependencias
    - [SetColumns](#SetColumns)
    - [UpdateMatrixSubform](#UpdateMatrixSubform)
#### [**ShowInTransitOnAfterValidate**](#procedimientos-2)
- Descripcion
    <p>Muestra en pagina despues de validar</p>
- Dependencias
    - [SetColumns](#SetColumns)
#### [**UpdateMatrixSubform**](#procedimientos-2)
- Descripcion
    <p>Actualiza el subformulario de la matriz</p>
- Dependencias
    - Ninguna
#### [**CustomGenerateMatrixData**](#procedimientos-2)
- Descripcion
    <p>Genera la matriz de datos</p>
- Dependencias
    - Ninguna
---
## [Page] ReplenPurchMatrixDetail
---
### [Tabla](#page-replenpurchmatrixdetail)
---
#### **FSN Replen. Template Matrix**
---
### [Acciones](#page-replenpurchmatrixdetail)
---
#### [**Period**](#acciones-3)
- Descripcion
    <p>Abre la pagina de periodo</p>
- Dependencias
    - Ninguna
#### [**Variant**](#acciones-3)
- Descripcion
    <p>Abre la pagina de variante</p>
- Dependencias
    - Ninguna
#### [**Location**](#acciones-3)
- Descripcion
    <p>Abre la pagina de ubicacion</p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#page-replenpurchmatrixdetail)
---
#### [**Load**](#procedimientos-3)
- Descripcion
    <p>Carga la pagina</p>
- Dependencias
    - Ninguna
#### [**SetVisible**](#procedimientos-3)
- Descripcion
    <p>Setea la visibilidad de los campos</p>
- Dependencias
    - Ninguna
#### [**OnValidateTmp**](#procedimientos-3)
- Descripcion
    <p>Valida el campo temporal, y actualiza la pagina</p>
- Dependencias
    - Ninguna
#### [**MATRIX_OnAfterGetRecordQty**](#procedimientos-3)
- Descripcion
    <p>Actualiza la cantidad despues de obtener el registro</p>
- Dependencias
    - [SetVisible](#setvisible)
#### [**MATRIX_OnAfterGetRecordAvg**](#procedimientos-3)
- Descripcion
    <p>Actualiza el promedio despues de obtener el registro</p>
- Dependencias
    - [SetVisible](#setvisible)
#### [**MATRIX_OnAfterGetRecordInv**](#procedimientos-3)
- Descripcion
    <p>Actualiza el inventario despues de obtener el registro</p>
- Dependencias
    - [SetVisible](#setvisible)
#### [**MATRIX_OnAfterGetRecordBon**](#procedimientos-3)
- Descripcion
    <p>Actualiza el bono despues de obtener el registro</p>
- Dependencias
    - [SetVisible](#setvisible)
#### [**OnOpenDetailForm**](#procedimientos-3)
- Descripcion
    <p>Abre el formulario de detalle</p>
- Dependencias
    - Ninguna
---
## [PageExt] PurchaseReplenishJournalExt
---
### [Campos Extras](#pageext-purchasereplenishjournalext)
---
- **"FSN Purch. Quantity"**
- **"FSN Purch. Unit of Measure"**
- **GlobalConsolidateNo**
---
### [Acciones](#pageext-purchasereplenishjournalext)
---
#### [**"Item Test Status"**](#acciones-4)
- Descripcion
    <p>prueba el estado del producto</p>
- Dependencias
    - Ninguna
#### [**"View Matrix"**](#acciones-4)
- Descripcion
    <p>Abre la pagina de matriz</p>
- Dependencias
    - Ninguna
#### [**"New Consolidate No."**](#acciones-4)
- Descripcion
    <p>Genera un nuevo numero de consolidacion</p>
- Dependencias
    - Ninguna
#### [**"FSN Create Consolidate Orders"**](#acciones-4)
- Descripcion
    <p>Genera ordenes de consolidacion</p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#pageext-purchasereplenishjournalext)
---
#### [**RefreshConsolidateNo**](#procedimientos-4)
- Descripcion
    <p>Refresca el numero de consolidacion si es FSN</p>
- Dependencias
    - Ninguna
---
## [PageExt] PurchReplenJrnlDetailsExt
---
### [Campos Extras](#pageext-purchreplenjrnldetailsext)
---
- **"Purch. Quantity"**
- **"UOM Purch."**
---
### [Acciones](#pageext-purchreplenjrnldetailsext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-purchreplenjrnldetailsext)
---
#### **Ninguno**
---
## [PageExt] ReplenItemStoreRecExt
---
### [Campos Extras](#pageext-replenitemstorerecext)
---
- **"FSN Division"**
- **"FSN Category"**
- **"FSN Product Group"**
- **"FSN Vendor Name"**
- **"FSN Minimum"**
- **"FSN Maximum"**
- **"FSN Approach Multiple"**
- **"FSN Purch. Multiple"**
- **"FSN Purch. Multiple"**
- **"FSN Transfer Multiple"**
- **"Attrib 1 Code"**
---
### [Acciones](#pageext-replenitemstorerecext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-replenitemstorerecext)
---
#### **Ninguno**
---
## [PageExt] ReplenSetupExt
---
### [Campos Extras](#pageext-replensetupext)
---
- **"FSN Consolidate Serie No."**
- **"FSN Approach Adjustment Type"**
- **"FSN Approach Multiple %"**
- **"FSN Transfer Consolidate No."**
---
### [Acciones](#pageext-replensetupext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-replensetupext)
---
#### **Ninguno**
---
## [PageExt] ReplenTemplateCardExt
---
### [Campos Extras](#pageext-replentemplatecardext)
---
- **"FSN Item Hierarchy Level Filter"**
- **"FSN Item Hierarchy Value Filter"**
- **"FSN Special Group Code Filter"**
- **"FSN Item Attribute Code Filter"**
- **"FSN Item Attribute Value Filter"**
---
### [Acciones](#pageext-replentemplatecardext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-replentemplatecardext)
---
#### **Ninguno**
---
## [PageExt] RetailPurchOrderListExt
---
### [Campos Extras](#pageext-retailpurchorderlistext)
---
- **"FSN Consolidate No."**
---
### [Acciones](#pageext-retailpurchorderlistext)
---
#### [**SetConsolidate**](#acciones-9)
- Descripcion
    <p>Setea el numero de consolidacion</p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#pageext-retailpurchorderlistext)
---
#### **Ninguno**
---
## [PageExt] RetailTransferOrderListExt
---
### [Campos Extras](#pageext-retailtransferorderlistext)
---
- **"FSN Consolidate No."**
---
### [Acciones](#pageext-retailtransferorderlistext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-retailtransferorderlistext)
---
#### **Ninguno**
---
## [PageExt] StockRequestExt
---
### [Campos Extras](#pageext-stockrequestext)
---
- **Ninguno**
---
### [Acciones](#pageext-stockrequestext)
---
#### [**"FSN authorization"**](#acciones-11)
- Descripcion
    <p>Carga la pagina de autorizacion FASANI Stock request </p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#pageext-stockrequestext)
---
#### **Ninguno**
---
## [PageExt] TransferReplenishJournalExt
---
### [Campos Extras](#pageext-transferreplenishjournalext)
---
- **"FSN Purch. Quantity"**
- **"FSN Purch. Unit of Measure"**
---
### [Acciones](#pageext-transferreplenishjournalext)
---
#### [**"FSN Create Consolidate Transfer"**](#acciones-12)
- Descripcion
    <p>Genera transferencias de consolidacion</p>
- Dependencias
    - Ninguna
---
### [Procedimientos](#pageext-transferreplenishjournalext)
---
#### **Ninguno**
---
## [PageExt] TransferReplenJrnDetailExt
---
### [Campos Extras](#pageext-transferreplenjrndetailext)
---
- **"Purch. Quantity"**
- **"UOM Purch."**
---
### [Acciones](#pageext-transferreplenjrndetailext)
---
#### **Ninguno**
---
### [Procedimientos](#pageext-transferreplenjrndetailext)
---
#### **Ninguno**
---
## [Query] GetPurchasePerVendor
---
### [Columnas](#query-getpurchasepervendor)
---
- **Vendor_Order_No_**
- **Order_Date**
- **FSN_Consolidate_No_**
- **Invoice_Discount_Value**
---
## [Reports] ReplenAutomaticRunFSN
---
## [Reports] ReplenishmentQtyByLocation
---
## [Tables] ReplenTemplateMatrix
---
### [Campos](#tables-replentemplatematrix)
---
- **"Replenishment Template Code"**
    - sin Validacion
- **"Batch No."**
    - sin Validacion
- **"Line No."**
    - sin Validacion
- **"Barcode No."**
    - sin Validacion
- **"Item No."**
    - sin Validacion
- **"Item No."**
    - sin Validacion
- **Description**
    - sin Validacion
- **"Direct Unit Cost"**
    - sin Validacion
- **"Vendor No."**
    - sin Validacion
- **"Vendor Name"**
    - sin Validacion
- **"Attrib 1 Code"**
    - sin Validacion
- **"Qty. per Unit of Measure"**
    - sin Validacion
- **"Purc. Unit of Measure"**
    - sin Validacion
---
### [Llaves](#tables-replentemplatematrix)
---
- **"Replenishment Template Code", "Batch No.", "Line No."**
---
## [Tables] LevelUpdate
---
### [Campos](#tables-levelupdate)
---
- **"Item No."**
    - sin Validacion
- **"Barcode"**
    - sin Validacion
- **"CD Level No."**
    - sin Validacion
- **"Date"**
    - sin Validacion
- **"Time"**
    - sin Validacion
- **"Unit of measure"**
    - sin Validacion
- **"Inventory CD"**
    - sin Validacion
- **"Code EBS"**
    - sin Validacion
---
### [Llaves](#tables-levelupdate)
---
- **"Item No."**
- **"Barcode"**
---
## [TablesExt] ReplenSetupExt
---
### [Campos Extras](#tablesext-replensetupext)
---
- **"FSN Consolidate Serie No."**
    - sin Validacion
- **"FSN Approach Multiple %"**
    - sin Validacion
- **"FSN Approach Adjustment Type"**
    - sin Validacion
- **"FSN Transfer Consolidate No."**
    - sin Validacion
---
### [Llaves](#tablesext-replensetupext)
---
- **Ninguna**
---
## [TablesExt] ReplenTemplateExt
---
### [Campos Extras](#tablesext-replentemplateext)
---
- **"FSN Consolidate No."**
    - sin Validacion
---
### [Llaves](#tablesext-replentemplateext)
---
- **Ninguna**
---
## [Version] 1.0.0.12
---
Se agrego un campo a la pagina [ReplenItemStoreRecExt](ReplenItemStoreRecExt)

---
## [Version] 1.0.0.11
---
Se creo una tabla [LevelUpdate](#tables-levelupdate) para registrar los niveles de inventario que se actualizan en el proceso de consolidacion, se agrego la accion [Validate Inventory](#validate-inventory) en la pagina [FSN_StockRequest](#page-fsn_stockrequest), para validar usando esa tabla si el nivel de inventario se actualizo en el proceso de consolidacion, si no se actualizo se muestra un mensaje de error y no se puede autorizar la solicitud de stock usando el procedimineto [ValidateInventory](#validateinventory), se agrego una validacion para que los items no se repitieran en las lineas de una misma solicitud [ValidateNotRepeatProducts](#ValidateNotRepeatProducts)
## [Version] 1.0.0.10
---
Se creo la pagina [Stock Request](#page-fsn_stockrequest) Para la asignacion de stock a los pedidos de compra y se creo la extension [Stock Request Ext](#pageext-stockrequestext) pagina para poder ver esta pagina desde "Solicitudes Stock"