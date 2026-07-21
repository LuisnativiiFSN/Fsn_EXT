<style>.page-header{margin:0 auto;font-family: Segoe UI Semibold;font-size: 10px;}.page-footer{margin-left: 50px;font-family:Segoe UI;font-size:9px}h1{font-size:28px}h2{font-size:26px}h3{font-size:23px}h4{font-size:22px}h5{font-size:20px}table{width:100%}#object-description{margin-top:-10px;margin-bottom:0px;}</style>

# DTE API Connection


Codeunit DTE API Connection (ID 50050).

## Properties

| Property | Value |
| --- | --- |
| Object Type | Codeunit |
| Object Subtype | Normal |
| Object ID | 50050 |
| Accessibility Level | Public | 

## Procedures

### `Get()`

Method to get the invoice from the DTE API.


#### Syntax

```al
[JsonObject] := Get(Uri: Text, request: HttpRequestMessage)
```

#### Parameters

*Uri*<br>
&emsp;Type: Text <br>

Text.

*request*<br>
&emsp;Type: HttpRequestMessage <br>


#### Return

*JsonObject*<br>

Return value of type Text.

### `Post()`


#### Syntax

```al
Post()
```

### `Post()`

Method to send a POST request to the DTE API.


#### Syntax

```al
[JsonObject] := Post(Uri: Text, request: HttpRequestMessage)
```

#### Parameters

*Uri*<br>
&emsp;Type: Text <br>

Text

*request*<br>
&emsp;Type: HttpRequestMessage <br>

HttpRequestMessage


#### Return

*JsonObject*<br>

Return Response body conntent

