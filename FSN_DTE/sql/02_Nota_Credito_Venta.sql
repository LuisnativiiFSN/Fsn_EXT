/*
    FSN CORRECTION DTE - NOTA DE CREDITO VENTA REGISTRADA
    Solo lectura: no contiene UPDATE, INSERT ni DELETE.

    Escriba los valores que desea probar. Deje NULL cuando el campo no cambia.
*/

SET NOCOUNT ON;

DECLARE
    @DocumentoNo       NVARCHAR(20) = N'NC000000003',
    @DTEInvoiceNuevo   NVARCHAR(31) = NULL,
    @DTEAuthNuevo      NVARCHAR(36) = NULL,
    @SignatureNuevo    NVARCHAR(50) = NULL,
    @DTEAbreviadoNuevo NVARCHAR(35) = NULL;


/*--------------------------------------------------------------------------------------
    VALIDACION
--------------------------------------------------------------------------------------*/

-- Datos actuales del documento.
SELECT
    dte.[No_],
    dte.[DTE Invoice],
    dte.[DTE AuthNumber],
    dte.[Signature Validation],
    info.[External Document No_],
    info.[Posting Date]
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
INNER JOIN dbo.[FASANI$Sales Cr_Memo Header$437dbf0e-84ff-417a-965d-ed2bb9650972] info
    ON info.[No_] = dte.[No_]
WHERE dte.[No_] = @DocumentoNo;

-- Detectar exactamente que campos cambiaron.
SELECT
    dte.[No_],
    dte.[DTE Invoice] AS [DTE Invoice actual],
    @DTEInvoiceNuevo AS [DTE Invoice nuevo],
    CASE
        WHEN @DTEInvoiceNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[DTE Invoice], N'') = @DTEInvoiceNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado DTE Invoice],
    dte.[DTE AuthNumber] AS [Codigo Generacion actual],
    @DTEAuthNuevo AS [Codigo Generacion nuevo],
    CASE
        WHEN @DTEAuthNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[DTE AuthNumber], N'') = @DTEAuthNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado Codigo Generacion],
    dte.[Signature Validation] AS [Sello Validacion actual],
    @SignatureNuevo AS [Sello Validacion nuevo],
    CASE
        WHEN @SignatureNuevo IS NULL THEN N'NO SOLICITADO'
        WHEN ISNULL(dte.[Signature Validation], N'') = @SignatureNuevo THEN N'SIN CAMBIO'
        ELSE N'CAMBIA'
    END AS [Estado Sello Validacion]
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34] dte
WHERE dte.[No_] = @DocumentoNo;

-- DTE Invoice: debe ser unico entre las notas de credito de venta.
SELECT TOP (1)
    [No_],
    [DTE Invoice]
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @DTEInvoiceNuevo IS NOT NULL
  AND [DTE Invoice] = @DTEInvoiceNuevo
  AND [No_] <> @DocumentoNo;

-- Codigo de generacion: debe ser unico.
SELECT TOP (1)
    [No_],
    [DTE AuthNumber]
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @DTEAuthNuevo IS NOT NULL
  AND [DTE AuthNumber] = @DTEAuthNuevo
  AND [No_] <> @DocumentoNo;

-- Sello de validacion: debe ser unico.
SELECT TOP (1)
    [No_],
    [Signature Validation]
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE @SignatureNuevo IS NOT NULL
  AND [Signature Validation] = @SignatureNuevo
  AND [No_] <> @DocumentoNo;

-- El DTE abreviado no debe existir en otra nota de credito de venta.
SELECT TOP (1)
    [No_],
    [External Document No_]
FROM dbo.[FASANI$Sales Cr_Memo Header$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE @DTEAbreviadoNuevo IS NOT NULL
  AND [External Document No_] = @DTEAbreviadoNuevo
  AND [No_] <> @DocumentoNo;


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
FROM dbo.[FASANI$Sales Cr_Memo Header$6961bd3e-336c-4dde-aeee-16842646cf34]
WHERE [No_] = @DocumentoNo;

SELECT
    [No_],
    [External Document No_]
FROM dbo.[FASANI$Sales Cr_Memo Header$437dbf0e-84ff-417a-965d-ed2bb9650972]
WHERE [No_] = @DocumentoNo;

SELECT
    [Entry No_],
    [Document No_],
    [Document Type],
    [External Document No_]
FROM dbo.[FASANI$Cust_ Ledger Entry$437dbf0e-84ff-417a-965d-ed2bb9650972]
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
  AND [Source Code] = N'VENTAS';

SELECT
    [Entry No_],
    [No_],
    [Sub Type],
    [External Document No_]
FROM dbo.[FASANI$Legal Ledger Entry$c2ec0fd9-a04f-49ff-8054-df8b17008af7]
WHERE [No_] = @DocumentoNo
  AND [Sub Type] = N'NC-V';

