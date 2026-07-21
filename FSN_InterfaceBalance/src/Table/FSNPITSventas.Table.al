table 50045 "FSN PITS_ventas"
{

    fields
    {
        field(10; CORRELATIVO; Code[20])
        {
            Description = 'Numero unico por registro';
        }
        field(20; FECHA_DOCUMENTO; Date)
        {
            Description = 'Fecha de creacion de documento en LDCOM';
        }
        field(30; SUCURSAL; Code[10])
        {
            Description = 'Numero de la sucursal en que se realizo la venta';
        }
        field(40; TIPO_TRANSACCION; Code[20])
        {
            Description = 'Tipo de Transaccion - Ticket=1, CreditoFiscal=2,ConsumidorFinal=3,NotaCredito=4';
        }
        field(45; NCF; Code[20])
        {
            Description = 'Numero de Documento';
        }
        field(50; SERIE_DOCUMENTO; Code[50])
        {
            Description = 'Numero de serie autorizado del documento';
        }
        field(60; DOCUMENTO_INICIAL; Code[50])
        {
            Description = 'En caso de recibo, el numero inicial';
        }
        field(70; DOCUMENTO_FINAL; Code[50])
        {
            Description = 'En caso de recibo, el numero final';
        }
        field(80; CODIGO_CLIENTE; Code[20])
        {
            Description = 'Codigo del cliente';
        }
        field(90; SUCURSAL_CLIENTE; Code[10])
        {
            Description = 'Numero de sucursal preferente';
        }
        field(95; REFERENCIA_CLIENTE_EBS; Code[20])
        {
        }
        field(100; NOMBRE_CLIENTE; Text[100])
        {
            Description = 'Nombre del cliente';
        }
        field(110; REGISTRO_CLIENTE; Text[30])
        {
            Description = 'NRC';
        }
        field(120; CAJA; Code[10])
        {
            Description = 'Numero de la caja';
        }
        field(130; TIPO_PAGO; Code[3])
        {
            Description = 'Credito/Contado (EF o CR)';
        }
        field(140; VALOR_VENTA_EXENTA; Decimal)
        {
            Description = 'Valor Exento';
        }
        field(150; REB_DEV_VTA_EXENTA; Decimal)
        {
            Description = 'Por ahora no utilizado';
        }
        field(160; VALOR_VENTA_GRABADA; Decimal)
        {
            Description = 'Valor Grabado';
        }
        field(170; REB_DEV_VTA_GRABADA; Decimal)
        {
            Description = 'Por ahora no utilizado';
        }
        field(180; EFECTIVO_DOMICILIO_A_RECIBIR; Decimal)
        {
            Description = 'Efectivo Domicilio a Remesar';
        }
        field(190; EFECTIVO_DOMICILIO_A_ENVIAR; Decimal)
        {
            Description = 'Efectivo Domicilio a Recibir';
        }
        field(200; VALOR_IVA; Decimal)
        {
            Description = 'Valor del IVA';
        }
        field(220; IVA_REB_DEV_VTA_GRABADA; Decimal)
        {
            Description = 'Valor del IVA en Devoluciones';
        }
        field(224; VALOR_CESC; Decimal)
        {
            Description = 'Valor del CESC';
        }
        field(226; CESC_REB_DEV_VTA_GRABADA; Decimal)
        {
            Description = 'Valor del CESC en Devoluciones';
        }
        field(230; TOTAL; Decimal)
        {
            Description = 'Total del documento';
        }
        field(240; TOTAL_EFECTIVO; Decimal)
        {
            Description = 'Valor Efectivo de la transaccion';
        }
        field(250; TOTAL_CREDITO; Decimal)
        {
            Description = 'Valor Credito de la transaccion';
        }
        field(260; TARJETA1_ID; Code[30])
        {
            Description = 'Codigo de medio de pago Tarjetas ATH';
        }
        field(270; TARJETA1_VALOR; Decimal)
        {
            Description = 'Valor cancelado ATH';
        }
        field(280; TARJETA2_ID; Code[30])
        {
            Description = 'Codigo de medio de pago Tarjetas CITI';
        }
        field(290; TARJETA2_VALOR; Decimal)
        {
            Description = 'Valor cancelado CITI';
        }
        field(292; TARJETA3_ID; Code[30])
        {
            Description = 'Codigo de medio de pago Tarjetas Credomatic';
        }
        field(294; TARJETA3_VALOR; Decimal)
        {
            Description = 'Valor cancelado Credomatic';
        }
        field(296; TARJETA4_ID; Code[30])
        {
            Description = 'Codigo de medio de pago Tarjeta Other';
        }
        field(298; TARJETA4_VALOR; Decimal)
        {
            Description = 'Valor cancelado Other';
        }
        field(300; VALIDADO; Date)
        {
            Description = 'Fecha de validacion registro';
        }
        field(310; APLICADO_AR; Date)
        {
            Description = 'Fecha de aplicacion en AR';
        }
        field(320; APLICADO_GL; Date)
        {
            Description = 'Fecha de aplicacion en GL';
        }
        field(330; STATUS_GRAL; Code[5])
        {
            Description = 'Flag del registro';
        }
        field(340; FECHA_DOC_ANULADO; Date)
        {
            Description = 'Fecha de anulacion documento';
        }
        field(350; NUMERO_DOC_ANULADO; Code[50])
        {
            Description = 'Numero de documento anulado';
        }
        field(360; BATCH_SOURCE; Code[25])
        {
            Description = 'Código de usuario que importa información de LDCOM';
        }
        field(370; USUARIO; Code[25])
        {
            Description = 'No utilizado';
        }
        field(380; FECHA_REGISTRO; Date)
        {
            Description = 'No utilizado';
        }
        field(390; MOSTRAR; Boolean)
        {
            Description = 'Si el libro lo utilizara';
        }
        field(400; MONTO_RETENCION; Decimal)
        {
            Description = 'Valor de retención';
        }
        field(405; MONTO_PERCEPCION; Decimal)
        {
            Description = 'Valor de percepción';
        }
        field(406; TARJETA5_ID; Code[10])
        {
            Description = 'Codigo de medio de pago Tarjetas Promerica';
        }
        field(407; TARJETA5_VALOR; Decimal)
        {
            Description = 'Valor cancelado Promerica';
        }
        field(408; TOTAL_PUNTOS; Decimal)
        {
            Description = 'Valor utilizado con media de pagos Puntos';
        }
        field(409; GIFTCARD; Decimal)
        {
            Description = 'Version 1 para giftcard fasani';
        }
        field(410; HUGO_PAY; Decimal)
        {
            Description = 'Valor Media pago HUGO';
        }
        field(411; BITCOIN; Decimal)
        {
            Description = 'Valor Media pago Bitcoin';
        }
        field(420; DTE_CODIGO_CONTROL; Text[50])
        {
        }
        field(430; DTE_CODIGO_GENERACION_INICIO; Text[50])
        {
        }
        field(440; DTE_CODIGO_GENERACION_FINAL; Text[50])
        {
        }
        field(450; DTE; Boolean)
        {
        }
        field(451; ANULADO; Boolean)
        {
        }
        field(452; "Replication Counter"; Integer)
        {

            trigger OnValidate()
            var
                FSNPITSventas: Record "FSN PITS_ventas";
            begin
                FSNPITSventas.RESET;
                FSNPITSventas.SETCURRENTKEY("Replication Counter");
                IF FSNPITSventas.FINDLAST THEN
                    "Replication Counter" := FSNPITSventas."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;
        }

    }

    keys
    {
        key(Key1; CORRELATIVO)
        {
            Clustered = true;
        }
        key(Key2; "Replication Counter")
        {
        }

    }

    fieldgroups
    {
    }

    trigger OnInsert()
    begin
        TestNoSeries;
        IF CORRELATIVO = '' THEN
            CORRELATIVO := NoSeriesMgt.GetNextNo(GetNoSeriesCode, WORKDATE, TRUE);
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;

    var
        SalesSetup: Record "Sales & Receivables Setup";
        NoSeriesMgt: Codeunit "NoSeriesManagement";

    local procedure TestNoSeries(): Boolean
    begin
        SalesSetup.GET;
        SalesSetup.TESTFIELD("FSN PITS Sales Nos.");
    end;

    local procedure GetNoSeriesCode(): Code[10]
    begin
        EXIT(SalesSetup."FSN PITS Sales Nos.");
    end;
}

