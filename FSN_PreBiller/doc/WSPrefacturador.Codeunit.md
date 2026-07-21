<style>.page-header{margin:0 auto;font-family: Segoe UI Semibold;font-size: 10px;}.page-footer{margin-left: 50px;font-family:Segoe UI;font-size:9px}h1{font-size:28px}h2{font-size:26px}h3{font-size:23px}h4{font-size:22px}h5{font-size:20px}table{width:100%}#object-description{margin-top:-10px;margin-bottom:0px;}</style>

# FSN WS Prefacturador


Codeunit FSN WS Prefacturador (ID 50093).

## Properties

| Property | Value |
| --- | --- |
| Object Type | Codeunit |
| Object Subtype | Normal |
| Object ID | 50093 |
| Accessibility Level | Public | 

## Procedures

### `AddLineinfocode()`


#### Syntax

```al
[Boolean] := AddLineinfocode(Codeinfocode: Code[10], input: Text, var ErrorTxt: Text[50], Quantity: integer)
```

#### Parameters

*Codeinfocode*<br>
&emsp;Type: Code[10] <br>

*input*<br>
&emsp;Type: Text <br>

*ErrorTxt*<br>
&emsp;Type: Text[50] <br>

*Quantity*<br>
&emsp;Type: integer <br>


### `ApplyCouponByCouponLine()`


#### Syntax

```al
ApplyCouponByCouponLine(CouponCode: Code[10], Store: Code[10], pClub: Code[10], pScheme: Code[10], pCustDiscGroup: Code[10])
```

#### Parameters

*CouponCode*<br>
&emsp;Type: Code[10] <br>

*Store*<br>
&emsp;Type: Code[10] <br>

*pClub*<br>
&emsp;Type: Code[10] <br>

*pScheme*<br>
&emsp;Type: Code[10] <br>

*pCustDiscGroup*<br>
&emsp;Type: Code[10] <br>


### `ApplyCouponByPerDiscLine()`


#### Syntax

```al
ApplyCouponByPerDiscLine(OfferNo_: Code[20], Store: Code[10], pClub: Code[10], pScheme: Code[10], pCustDiscGroup: Code[10])
```

#### Parameters

*OfferNo_*<br>
&emsp;Type: Code[20] <br>

*Store*<br>
&emsp;Type: Code[10] <br>

*pClub*<br>
&emsp;Type: Code[10] <br>

*pScheme*<br>
&emsp;Type: Code[10] <br>

*pCustDiscGroup*<br>
&emsp;Type: Code[10] <br>


### `ApplyGetMemberType()`


#### Syntax

```al
ApplyGetMemberType(pMembershipCard: Text[100], var pClubCode: Code[10], var pSchemeCode: Code[10], var pCustDiscGroup: Code[10])
```

#### Parameters

*pMembershipCard*<br>
&emsp;Type: Text[100] <br>

*pClubCode*<br>
&emsp;Type: Code[10] <br>

*pSchemeCode*<br>
&emsp;Type: Code[10] <br>

*pCustDiscGroup*<br>
&emsp;Type: Code[10] <br>


### `GetMemberinfoExt()`


#### Syntax

```al
GetMemberinfoExt(VAR MemberCardNo: Code[20])
```

#### Parameters

*VAR MemberCardNo*<br>
&emsp;Type: Code[20] <br>


### `GetNombreCliente()`


#### Syntax

```al
[Text] := GetNombreCliente(var gRecRef: RecordRef)
```

#### Parameters

*gRecRef*<br>
&emsp;Type: RecordRef <br>


### `GetItemByKey()`

Get Item by Key to be used in the prebiller


#### Syntax

```al
[JsonObject] := GetItemByKey(Item: Record Item)
```

#### Parameters

*Item*<br>
&emsp;Type: Record  Item<br>

Recibe una tabla filtrada de Items


#### Return

*JsonObject*<br>

On Objeto de Json

### `GetCustomerByKey()`


#### Syntax

```al
[JsonObject] := GetCustomerByKey(Cust: Record Customer)
```

#### Parameters

*Cust*<br>
&emsp;Type: Record  Customer<br>


### `GetMemberCardByKey()`


#### Syntax

```al
[JsonObject] := GetMemberCardByKey(MemberCard: Record "LSC Membership Card")
```

#### Parameters

*MemberCard*<br>
&emsp;Type: Record  "LSC Membership Card"<br>


### `AddCustLine()`


#### Syntax

```al
[Boolean] := AddCustLine(Line No.: integer, var Response_Code: Text[10], var Response_Text: Text)
```

#### Parameters

*Line No.*<br>
&emsp;Type: integer <br>

*Response_Code*<br>
&emsp;Type: Text[10] <br>

*Response_Text*<br>
&emsp;Type: Text <br>


### `CompressArrayProcess()`


#### Syntax

```al
CompressArrayProcess()
```

### `CustomCheckMemberCard()`


#### Syntax

```al
[Boolean] := CustomCheckMemberCard(CI: Text, REC: Record "LSC POS Transaction")
```

#### Parameters

*CI*<br>
&emsp;Type: Text <br>

*REC*<br>
&emsp;Type: Record  "LSC POS Transaction"<br>


### `DeletePOSTransaction()`


#### Syntax

```al
DeletePOSTransaction(ReceiptNo: Code[20])
```

#### Parameters

*ReceiptNo*<br>
&emsp;Type: Code[20] <br>


### `GetCustomerList()`

Obtiene una lista de CLientes bajo un filtro


#### Syntax

```al
GetCustomerList(Json: Text, var res: Text)
```

#### Parameters

*Json*<br>
&emsp;Type: Text <br>

Objeto de filtro

*res*<br>
&emsp;Type: Text <br>

arreglo de objetos de resultado


### `GetItemByKey()`

GetItemByKey.


#### Syntax

```al
GetItemByKey(ItemNo: Code[20], var Response_Text: Text, var Response_Code: Text)
```

#### Parameters

*ItemNo*<br>
&emsp;Type: Code[20] <br>

Code[20].

*Response_Text*<br>
&emsp;Type: Text <br>

VAR Text.

*Response_Code*<br>
&emsp;Type: Text <br>

VAR Text.


### `GetItemList()`

recibe algun parametro y si devuelve una lista de productos


#### Syntax

```al
GetItemList(Json: Text, var res: Text, var Code: Text)
```

#### Parameters

*Json*<br>
&emsp;Type: Text <br>

json con los objetos de filtro

*res*<br>
&emsp;Type: Text <br>

Texto de respuesta

*Code*<br>
&emsp;Type: Text <br>

Codigo de respuesta


### `GetMemberCardsByCust()`

carga todas las tarjetas asociadas a un cliente


#### Syntax

```al
GetMemberCardsByCust(CustomerNo: Code[20], var res: Text)
```

#### Parameters

*CustomerNo*<br>
&emsp;Type: Code[20] <br>

Codigo del cliente

*res*<br>
&emsp;Type: Text <br>

arreglo de Json con todas las tarjetas


### `GetValidPriceGroup()`


#### Syntax

```al
[Code[10]] := GetValidPriceGroup(CardNo: text)
```

#### Parameters

*CardNo*<br>
&emsp;Type: text <br>


### `InitLineFreeText()`


#### Syntax

```al
InitLineFreeText(pFreeText: Text, pReceiptContext: Code[20])
```

#### Parameters

*pFreeText*<br>
&emsp;Type: Text <br>

*pReceiptContext*<br>
&emsp;Type: Code[20] <br>


### `initReceiptModal()`


#### Syntax

```al
initReceiptModal(pReceipt: Code[20], pSource: Code[20])
```

#### Parameters

*pReceipt*<br>
&emsp;Type: Code[20] <br>

*pSource*<br>
&emsp;Type: Code[20] <br>


### `insertTransaction()`


#### Syntax

```al
[Code[20]] := insertTransaction()
```

### `MemberCardReplace()`


#### Syntax

```al
MemberCardReplace(var XMLRequest: Text, var XMLResponse: Text, var RequestID: Text[50])
```

#### Parameters

*XMLRequest*<br>
&emsp;Type: Text <br>

*XMLResponse*<br>
&emsp;Type: Text <br>

*RequestID*<br>
&emsp;Type: Text[50] <br>


### `RecalcEcommerOfferPrice2()`


#### Syntax

```al
RecalcEcommerOfferPrice2()
```

### `RecalcProcess()`


#### Syntax

```al
RecalcProcess()
```

### `EditNonPaymentTrack()`


#### Syntax

```al
[Text] := EditNonPaymentTrack(pTrack: Text)
```

#### Parameters

*pTrack*<br>
&emsp;Type: Text <br>


### `Trim()`


#### Syntax

```al
[Text[1024]] := Trim(String_in: Text, Len: integer)
```

#### Parameters

*String_in*<br>
&emsp;Type: Text <br>

*Len*<br>
&emsp;Type: integer <br>


### `ValidateAgricolaCard()`


#### Syntax

```al
[Boolean] := ValidateAgricolaCard(Bin: Code[6])
```

#### Parameters

*Bin*<br>
&emsp;Type: Code[6] <br>


### `WSXMLStandar()`


#### Syntax

```al
WSXMLStandar(var XMLRequest: Text, var XMLResponse: Text, var RequestID: Text[50])
```

#### Parameters

*XMLRequest*<br>
&emsp;Type: Text <br>

*XMLResponse*<br>
&emsp;Type: Text <br>

*RequestID*<br>
&emsp;Type: Text[50] <br>


### `GetReceiptNo()`


#### Syntax

```al
[Code[20]] := GetReceiptNo(var LastReceiptNo: Code[20], RequestFromID_l: Code[20], CalcOnly: Boolean)
```

#### Parameters

*LastReceiptNo*<br>
&emsp;Type: Code[20] <br>

*RequestFromID_l*<br>
&emsp;Type: Code[20] <br>

*CalcOnly*<br>
&emsp;Type: Boolean <br>


### `inventoryRecalculation()`


#### Syntax

```al
[Boolean] := inventoryRecalculation(Item No.: Code[10], StoreNo: Code[10], TerminalNo: Code[10], var Error: integer)
```

#### Parameters

*Item No.*<br>
&emsp;Type: Code[10] <br>

*StoreNo*<br>
&emsp;Type: Code[10] <br>

*TerminalNo*<br>
&emsp;Type: Code[10] <br>

*Error*<br>
&emsp;Type: integer <br>


### `EcommerceFunctions()`


#### Syntax

```al
[Text] := EcommerceFunctions(XRequest: Text, XCommand: Text[50])
```

#### Parameters

*XRequest*<br>
&emsp;Type: Text <br>

*XCommand*<br>
&emsp;Type: Text[50] <br>


### `OnWSXmlStandarRun()`


#### Syntax

```al
OnWSXmlStandarRun(var XMLRequest: Text, var XMLResponse: Text, var RequestID: Text[50], var IsHandled: Boolean)
```

#### Parameters

*XMLRequest*<br>
&emsp;Type: Text <br>

*XMLResponse*<br>
&emsp;Type: Text <br>

*RequestID*<br>
&emsp;Type: Text[50] <br>

*IsHandled*<br>
&emsp;Type: Boolean <br>


