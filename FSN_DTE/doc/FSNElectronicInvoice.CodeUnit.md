<style>.page-header{margin:0 auto;font-family: Segoe UI Semibold;font-size: 10px;}.page-footer{margin-left: 50px;font-family:Segoe UI;font-size:9px}h1{font-size:28px}h2{font-size:26px}h3{font-size:23px}h4{font-size:22px}h5{font-size:20px}table{width:100%}#object-description{margin-top:-10px;margin-bottom:0px;}</style>

# FSN Electronic Invoice


Codeunit FSN Electronic Invoice (ID 50049).

## Properties

| Property | Value |
| --- | --- |
| Object Type | Codeunit |
| Object Subtype | Normal |
| Object ID | 50049 |
| Accessibility Level | Public | 

## Procedures

### `SendWithContingency()`

SendWithContingency.
Send the invoice to the web service with contingency.


#### Syntax

```al
SendWithContingency(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

Record "LSC Transaction Header".


### `CreateInvoice()`

CreateInvoice.
create a JSON object with the information of the invoice to be sent to the web service.


#### Syntax

```al
[JsonObject] := CreateInvoice(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

Record "LSC Transaction Header".


#### Return

*JsonObject*<br>

Return value of type JsonObject.

### `GenerateAndSendAnulation()`

GenerateAndSendAnulation.
Generate a JSON object with the information of the invoice to be sent to the web service.


#### Syntax

```al
GenerateAndSendAnulation(var Transaction: Record "LSC Transaction Header")
```

#### Parameters

*Transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

VAR Record "LSC Transaction Header".


### `saveInvoice()`

saveInvoice.
this procedure save the invoice information in the table "FSN DTE Transaction Header".


#### Syntax

```al
saveInvoice(request: JsonObject, response: JsonObject, transaction: Record "LSC Transaction Header")
```

#### Parameters

*request*<br>
&emsp;Type: JsonObject <br>

JsonObject.

*response*<br>
&emsp;Type: JsonObject <br>

JsonObject.

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

Record "LSC Transaction Header".


### `trimTerminal()`

trimTerminal.
this procedure remove the '#' character from the terminal.


#### Syntax

```al
[Text] := trimTerminal(_terminal: Text)
```

#### Parameters

*_terminal*<br>
&emsp;Type: Text <br>

Text.


#### Return

*Text*<br>

Return value of type Text.

### `convertJsonToTransaction()`


#### Syntax

```al
convertJsonToTransaction(var jsonRequest: Text)
```

#### Parameters

*jsonRequest*<br>
&emsp;Type: Text <br>


### `CreateAnulation()`


#### Syntax

```al
[JsonObject] := CreateAnulation(var Transaction: Record "LSC Transaction Header")
```

#### Parameters

*Transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `createLog()`


#### Syntax

```al
createLog(request: JsonObject, response: JsonObject, transaction: Record "LSC Transaction Header")
```

#### Parameters

*request*<br>
&emsp;Type: JsonObject <br>

*response*<br>
&emsp;Type: JsonObject <br>

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `evaluateTotalByDocumentType()`


#### Syntax

```al
[Variant] := evaluateTotalByDocumentType(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getActivityDesc()`


#### Syntax

```al
[Text] := getActivityDesc(DTEActivityCode: Code[6])
```

#### Parameters

*DTEActivityCode*<br>
&emsp;Type: Code[6] <br>


### `getAddress()`


#### Syntax

```al
[JsonToken] := getAddress(customer: Record Customer)
```

#### Parameters

*customer*<br>
&emsp;Type: Record  Customer<br>


### `getAddress()`


#### Syntax

```al
[JsonObject] := getAddress(store: Record "LSC Store")
```

#### Parameters

*store*<br>
&emsp;Type: Record  "LSC Store"<br>


### `getAdenda()`


#### Syntax

```al
[JsonToken] := getAdenda(keys: List of [Text], values: List of [Text])
```

#### Parameters

*keys*<br>
&emsp;Type: List  of [Text]<br>

*values*<br>
&emsp;Type: List  of [Text]<br>


### `getBienTitulo()`


#### Syntax

```al
[JsonValue] := getBienTitulo(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getCredentials()`


#### Syntax

```al
[Text] := getCredentials()
```

### `getCreditPurchase()`


#### Syntax

```al
[JsonToken] := getCreditPurchase(var posCardEntry: Record "LSC POS Card Entry")
```

#### Parameters

*posCardEntry*<br>
&emsp;Type: Record  "LSC POS Card Entry"<br>


### `getCustomer()`


#### Syntax

```al
[JsonObject] := getCustomer(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getDocumentPerItem()`


#### Syntax

```al
[JsonToken] := getDocumentPerItem(transSalesEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*transSalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `getDocumentType()`


#### Syntax

```al
[Text] := getDocumentType(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getItemName()`


#### Syntax

```al
[Text] := getItemName(transSalasEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*transSalasEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `getParams()`


#### Syntax

```al
[Boolean] := getParams()
```

### `getParamsMaster()`


#### Syntax

```al
[Boolean] := getParamsMaster()
```

### `getMasterTerminal()`


#### Syntax

```al
[Text] := getMasterTerminal()
```

### `getPaymentList()`


#### Syntax

```al
[JsonToken] := getPaymentList(transaction: Record "LSC Transaction Header", var paymentMethod: Text, var globalDiscount: Decimal)
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*paymentMethod*<br>
&emsp;Type: Text <br>

*globalDiscount*<br>
&emsp;Type: Decimal <br>


### `getPrice()`


#### Syntax

```al
[Text] := getPrice(docType: Enum "FSN Transaction Document Type", transSalesEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*docType*<br>
&emsp;Type: Enum  "FSN Transaction Document Type"<br>

*transSalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `getProductDisc()`


#### Syntax

```al
[Text] := getProductDisc(docType: Enum "FSN Transaction Document Type", transSalesEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*docType*<br>
&emsp;Type: Enum  "FSN Transaction Document Type"<br>

*transSalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `getProductList()`


#### Syntax

```al
[JsonArray] := getProductList(var transSalesEntry: Record "LSC Trans. Sales Entry", docType: Enum "FSN Transaction Document Type", var sellerCode: Text, var globalDiscount: Decimal)
```

#### Parameters

*transSalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>

*docType*<br>
&emsp;Type: Enum  "FSN Transaction Document Type"<br>

*sellerCode*<br>
&emsp;Type: Text <br>

*globalDiscount*<br>
&emsp;Type: Decimal <br>


### `getProductType()`


#### Syntax

```al
[text] := getProductType(item: Record Item)
```

#### Parameters

*item*<br>
&emsp;Type: Record  Item<br>


### `getQty()`


#### Syntax

```al
[Text] := getQty(transSalesEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*transSalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `getRemissionSequence()`


#### Syntax

```al
[Code[20]] := getRemissionSequence(terminal: Text)
```

#### Parameters

*terminal*<br>
&emsp;Type: Text <br>


### `getSequential()`


#### Syntax

```al
[Text] := getSequential(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getStore()`


#### Syntax

```al
[JsonObject] := getStore(transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


### `getTaxInformation()`


#### Syntax

```al
[JsonObject] := getTaxInformation(customer: Record Customer)
```

#### Parameters

*customer*<br>
&emsp;Type: Record  Customer<br>


### `getTotals()`


#### Syntax

```al
[JsonObject] := getTotals(var transaction: Record "LSC Transaction Header", globalDiscount: Decimal)
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*globalDiscount*<br>
&emsp;Type: Decimal <br>


### `getTotalsRemission()`


#### Syntax

```al
[JsonObject] := getTotalsRemission(var transaction: Record "LSC Transaction Header", globalDiscount: Decimal)
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*globalDiscount*<br>
&emsp;Type: Decimal <br>


### `sendToRemission()`


#### Syntax

```al
sendToRemission(jObject: JsonObject)
```

#### Parameters

*jObject*<br>
&emsp;Type: JsonObject <br>


### `serializeDecimal()`


#### Syntax

```al
[Text] := serializeDecimal(mount: Decimal)
```

#### Parameters

*mount*<br>
&emsp;Type: Decimal <br>


### `UpdateInvoice()`


#### Syntax

```al
UpdateInvoice(request: JsonObject, response: JsonObject)
```

#### Parameters

*request*<br>
&emsp;Type: JsonObject <br>

*response*<br>
&emsp;Type: JsonObject <br>


### `getLinesRemission()`


#### Syntax

```al
[Boolean] := getLinesRemission(var SalesEntry: Record "LSC Trans. Sales Entry")
```

#### Parameters

*SalesEntry*<br>
&emsp;Type: Record  "LSC Trans. Sales Entry"<br>


### `existsDTE()`


#### Syntax

```al
[Boolean] := existsDTE(var POSMenuLine: Record "LSC POS Menu Line")
```

#### Parameters

*POSMenuLine*<br>
&emsp;Type: Record  "LSC POS Menu Line"<br>


### `printInvoice()`


#### Syntax

```al
printInvoice(POSMenuLine: Record "LSC POS Menu Line")
```

#### Parameters

*POSMenuLine*<br>
&emsp;Type: Record  "LSC POS Menu Line"<br>


### `getHolderAndBeneficiary()`


#### Syntax

```al
getHolderAndBeneficiary(transaction: Record "LSC Transaction Header", var holder: Text, var beneficiary: Text)
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*holder*<br>
&emsp;Type: Text <br>

*beneficiary*<br>
&emsp;Type: Text <br>


### `OnBeforePrintSalesSlip()`


#### Syntax

```al
OnBeforePrintSalesSlip(var Sender: Codeunit "LSC POS Print Utility", var Transaction: Record "LSC Transaction Header", var PrintBuffer: Record "LSC POS Print Buffer", var PrintBufferIndex: Integer, var LinesPrinted: Integer, var IsHandled: Boolean, var ReturnValue: Boolean)
```

#### Parameters

*Sender*<br>
&emsp;Type: Codeunit  "LSC POS Print Utility"<br>

*Transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*PrintBuffer*<br>
&emsp;Type: Record  "LSC POS Print Buffer"<br>

*PrintBufferIndex*<br>
&emsp;Type: Integer <br>

*LinesPrinted*<br>
&emsp;Type: Integer <br>

*IsHandled*<br>
&emsp;Type: Boolean <br>

*ReturnValue*<br>
&emsp;Type: Boolean <br>


### `OnInvokeGlobalChannelEvent()`


#### Syntax

```al
OnInvokeGlobalChannelEvent(var XMLRequest: Text, var XMLResponse: Text, var RequestID: Text[50], var POSMenuLine: Record "LSC POS Menu Line", var Processed: Boolean, var MsgResult: Text)
```

#### Parameters

*XMLRequest*<br>
&emsp;Type: Text <br>

*XMLResponse*<br>
&emsp;Type: Text <br>

*RequestID*<br>
&emsp;Type: Text[50] <br>

*POSMenuLine*<br>
&emsp;Type: Record  "LSC POS Menu Line"<br>

*Processed*<br>
&emsp;Type: Boolean <br>

*MsgResult*<br>
&emsp;Type: Text <br>


### `OnButtonPressed()`


#### Syntax

```al
OnButtonPressed(var POSMenuLine: Record "LSC POS Menu Line", var handled: Boolean)
```

#### Parameters

*POSMenuLine*<br>
&emsp;Type: Record  "LSC POS Menu Line"<br>

*handled*<br>
&emsp;Type: Boolean <br>


### `OnAfterCreateInvoice()`


#### Syntax

```al
OnAfterCreateInvoice(transaction: Record "LSC Transaction Header", var json: JsonObject)
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>

*json*<br>
&emsp;Type: JsonObject <br>


### `OnBeforeCreateInvoice()`


#### Syntax

```al
OnBeforeCreateInvoice(var transaction: Record "LSC Transaction Header")
```

#### Parameters

*transaction*<br>
&emsp;Type: Record  "LSC Transaction Header"<br>


