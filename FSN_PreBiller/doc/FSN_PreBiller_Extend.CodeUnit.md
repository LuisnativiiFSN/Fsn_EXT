<style>.page-header{margin:0 auto;font-family: Segoe UI Semibold;font-size: 10px;}.page-footer{margin-left: 50px;font-family:Segoe UI;font-size:9px}h1{font-size:28px}h2{font-size:26px}h3{font-size:23px}h4{font-size:22px}h5{font-size:20px}table{width:100%}#object-description{margin-top:-10px;margin-bottom:0px;}</style>

# FSN PreBiller Extend


Codeunit FSN PreBiller Extend (ID 50084).

## Properties

| Property | Value |
| --- | --- |
| Object Type | Codeunit |
| Object Subtype | Normal |
| Object ID | 50084 |
| Accessibility Level | Public | 

## Procedures

### `GetLastReceiptNumber()`

busca el ultimo numero de la secuencia de recibo de prefacturador y lo incrementa en 1


#### Syntax

```al
[Code[20]] := GetLastReceiptNumber(Terminal: Text)
```

#### Parameters

*Terminal*<br>
&emsp;Type: Text <br>

No. Terminal


#### Return

*ReceiptNo: Code[20]*<br>

Numero de recibo ya incrementado en 1

### `GetValidCustDiscGroup()`

Obtiene el grupo de descuento del cliente por su tarjeta de membresia


#### Syntax

```al
[Code[20]] := GetValidCustDiscGroup(MemberCardNo: Code[20])
```

#### Parameters

*MemberCardNo*<br>
&emsp;Type: Code[20] <br>

No. tarjeta


#### Return

*CustDiscGroup: Code[20]*<br>

devuelve el grupo de descuento a aplicar

### `GetDiscGroupByCustomer()`

Obtiene el grupo de descuento del cliente por su ID


#### Syntax

```al
[Code[20]] := GetDiscGroupByCustomer(CustomerNo: Code[20], CurrentDiscGroup: Code[20])
```

#### Parameters

*CustomerNo*<br>
&emsp;Type: Code[20] <br>

Codigo de Cliente

*CurrentDiscGroup*<br>
&emsp;Type: Code[20] <br>

grupo por defecto


#### Return

*CustDiscGroup: Code[20]*<br>

Devuelve el grupo de descuento del cliente

### `ProcessCustomer()`




#### Syntax

```al
ProcessCustomer(REC: Record "LSC POS transaction")
```

#### Parameters

*REC*<br>
&emsp;Type: Record  "LSC POS transaction"<br>




### `MemberCardValidityStatus()`


#### Syntax

```al
[Boolean] := MemberCardValidityStatus(MemberCardNo: Code[20])
```

#### Parameters

*MemberCardNo*<br>
&emsp;Type: Code[20] <br>


