/*
    FSN CORRECTION DTE - NOTA DE CREDITO COMPRA REGISTRADA
    Solo lectura: no contiene UPDATE, INSERT ni DELETE.

    Escriba los valores que desea probar. Deje NULL cuando el campo no cambia.
*/

SET NOCOUNT ON;

DECLARE
    @DocumentoNo       NVARCHAR(20) = N'NC000000011'


/*--------------------------------------------------------------------------------------
    VALIDACION
--------------------------------------------------------------------------------------*/

-- Datos actuales: DTE, proveedor, fecha y DTE abreviado.
SELECT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation],
    info.[Buy-from Vendor No_],
    info.[Vendor Cr_ Memo No_],
    info.[Posting Date],
    info.[Document Date],
    info.[Source Code]
FROM dbo.[FASANI$Purch_ Cr_ Memo Hdr_$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Purch_ Cr_ Memo Hdr_$437dbf0e-84ff-417a-965d-ed2bb9650972] info
    ON info.[No_] = dte.[No_]
WHERE dte.[No_] = @DocumentoNo;



/*--------------------------------------------------------------------------------------
    MODIFICACION - FILAS QUE SERIAN AFECTADAS

    DTE AuthNumber y Signature Validation solo afectan el encabezado DTE.
    Las tablas del DTE abreviado solo se afectan cuando cambia DTE Invoice.
--------------------------------------------------------------------------------------*/

SELECT
    [No_],
    [DTE Invoice],
    [DTE AuthNumber],
    [Signature Validation]
FROM dbo.[FASANI$Purch_ Cr_ Memo Hdr_$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE [No_] = @DocumentoNo;

SELECT
    [No_],
    [Vendor Cr_ Memo No_]
FROM dbo.[FASANI$Purch_ Cr_ Memo Hdr_$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [No_] = @DocumentoNo;

SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [External Document No_]
FROM dbo.[FASANI$Vendor Ledger Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 3;

SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [Source Code],
    [External Document No_]
FROM dbo.[FASANI$G_L Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [Document No_] = @DocumentoNo
  AND [Document Type] = 3
  AND [Source Code] = N'COMPRAS';

SELECT
    [No_],
    [Sub Type],
    [External Document No_]
FROM dbo.[FASANI$Legal Ledger Entry$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo
  AND [Sub Type] = N'NC-C';

