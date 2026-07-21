# EXTENSION DE AUTOGESTION DE DESCUENTOS 

<h1>INDICE</h1>
    
- CodeUnits
    - [Self-MgmtOffers](#codeunit-self-mgmtoffers)
- Pages
    - [Self-MgmtOffers](#tipo-de-arcvhivo-nombre-del-archivo)
    - [Self-MgmtOffersRec](#tipo-de-arcvhivo-nombre-del-archivo)
- Tables
    - [Self-MgmtOffers](#tipo-de-arcvhivo-nombre-del-archivo)
- Versions
    - [1.0.0.0](#version-numero-de-version)
---
## [CodeUnit] Self-MgmtOffers
---
### [Procediminetos globales](#codeunit-self-mgmtoffers)
---
#### [**PushOffers**](#procediminetos-globales)
- Descripcion
    <p>Setea los parametros globales para ejecutar la tarea programada</p>
- Dependencias
    - [SelectGroupType](#selectgrouptype)
    - [SelectDiscGroup](#selectdiscgroup)
    - [CheckFunction](#checkfunction)

### [**DeleteOffer**](#procediminetos-globales)
- Descripcion
    <p>Elimina la oferta seleccionada</p>
- Dependencias
    - Ninguna

### [**ModifyOffer**](#procediminetos-globales)
- Descripcion
    <p>Modifica la oferta seleccionada</p>
- Dependencias
    - Ninguna

### [**InsertOffer**](#procediminetos-globales)
- Descripcion
    <p>Inserta una nueva oferta</p>
- Dependencias
    - [ModifyOffer](#modifyoffer)
    - [GetLastNo](#getlastno)
    - [GetType](#gettype)

### [**CheckFunction**](#procediminetos-globales)
- Descripcion
    <p>Verifica que la operacion a realizar dependiendo de los datos</p>
- Dependencias
    - [DeleteOffer](#deleteoffer)
    - [InsertOffer](#insertoffer)

### [**SelectGroupType**](#procediminetos-globales)
- Descripcion
    <p>Selecciona el tipo de grupo de descuento</p>
- Dependencias
    - Ninguna

### [**SelectDiscGroup**](#procediminetos-globales)
- Descripcion
    <p>Selecciona el grupo de descuento</p>
- Dependencias
    - Ninguna

### [**GetLastNo**](#procediminetos-globales)
- Descripcion
    <p>Obtiene el ultimo numero de oferta</p>
- Dependencias
    - Ninguna

### [**GetType**](#procediminetos-globales)
- Descripcion
    <p>Obtiene el tipo de oferta</p>
- Dependencias
    - Ninguna
---
## [Page] Self-MgmtOffers
---
### [Campos](#page-self-mgmtoffers)
---
#### [**Filter**](#campos)
#### [**Offer Type**](#campos)
#### [**Bank name**](#campos)
#### [**Store**](#campos)
#### [**Start Date**](#campos)
#### [**End Date**](#campos)
#### [**Type**](#campos)
#### [**Item No.**](#campos)
#### [**Item Description**](#campos)
#### [**Unit of measure**](#campos)
#### [**% Discount**](#campos)
#### [**Price**](#campos)
#### [**Discount Group**](#campos)
#### [**Sell Out**](#campos)
#### [**Sell Out Value**](#campos)
#### [**Web Category Type**](#campos)
#### [**Web Category name**](#campos)
#### [**Web Category start date**](#campos)
#### [**Web Category end date**](#campos)
---
### [Acciones](#page-self-mgmtoffers)
---
#### [**Mass load**](#acciones)
- Descripcion
    <p>Carga masiva de Productos para aplicarles nuevas ofertas</p>
- Dependencias
    - Ninguna

#### [**Confirm Offer**](#acciones)
- Descripcion
    <p>Confirma la oferta seleccionada para guardar en la tabla real</p>
- Dependencias
    - Ninguna

#### [**Check Record**](#acciones)
- Descripcion
    <p>Verifica que el registro de las ofertas</p>
- Dependencias
    - Ninguna
---
## [Page] Self-MgmtOffersRec
---
### [Campos](#page-self-mgmtoffersrec)
---
#### [**Offer Type**](#campos)
#### [**Bank name**](#campos)
#### [**Store**](#campos)
#### [**Start Date**](#campos)
#### [**End Date**](#campos)
#### [**Type**](#campos)
#### [**Item No.**](#campos)
#### [**Item Description**](#campos)
#### [**Unit of measure**](#campos)
#### [**% Discount**](#campos)
#### [**Price**](#campos)
#### [**Discount Group**](#campos)
#### [**Sell Out**](#campos)
#### [**Sell Out Value**](#campos)
#### [**Web Category Type**](#campos)
#### [**Web Category name**](#campos)
#### [**Web Category start date**](#campos)
#### [**Web Category end date**](#campos)
---
## [Table] Self-MgmtOffers
---
### [Campos](#table-self-mgmtoffers)
---
#### [**Offer Type**](#campos)
#### [**Bank name**](#campos)
#### [**Store**](#campos)
#### [**Start Date**](#campos)
#### [**End Date**](#campos)
#### [**Type**](#campos)
#### [**Item No.**](#campos)
#### [**Item Description**](#campos)
#### [**Unit of measure**](#campos)
#### [**% Discount**](#campos)
#### [**Price**](#campos)
#### [**Discount Group**](#campos)
#### [**Sell Out**](#campos)
#### [**Sell Out Value**](#campos)
#### [**Web Category Type**](#campos)
#### [**Web Category name**](#campos)
#### [**Web Category start date**](#campos)
#### [**Web Category end date**](#campos)
---
## [Version] 1.0.0.0
---
Creacion de proyecto para la gestion de ofertas de productos para los usuarios 