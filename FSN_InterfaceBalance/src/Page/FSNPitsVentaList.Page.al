page 50106 "FSN PITS VENTAS"
{
    PageType = List;
    SourceTable = 50045;
    ApplicationArea = All;
    UsageCategory = Administration;
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(CORRELATIVO; CORRELATIVO)
                {
                }
                field(FECHA_DOCUMENTO; FECHA_DOCUMENTO)
                {
                }
                field(SUCURSAL; SUCURSAL)
                {
                }
                field(TIPO_TRANSACCION; TIPO_TRANSACCION)
                {
                }
                field(NCF; NCF)
                {
                }
                field(SERIE_DOCUMENTO; SERIE_DOCUMENTO)
                {
                }
                field(DOCUMENTO_INICIAL; DOCUMENTO_INICIAL)
                {
                }
                field(DOCUMENTO_FINAL; DOCUMENTO_FINAL)
                {
                }
                field(DTE; DTE)
                {
                }
                field(ANULADO; ANULADO)
                {
                    Caption = 'DTE ANULADO';
                }
                field(DTE_CODIGO_CONTROL; DTE_CODIGO_CONTROL)
                {
                }
                field(DTE_CODIGO_GENERACION_INICIO; DTE_CODIGO_GENERACION_INICIO)
                {
                }
                field(DTE_CODIGO_GENERACION_FINAL; DTE_CODIGO_GENERACION_FINAL)
                {
                }
                field(CODIGO_CLIENTE; CODIGO_CLIENTE)
                {
                }
                field(SUCURSAL_CLIENTE; SUCURSAL_CLIENTE)
                {
                }
                field(REFERENCIA_CLIENTE_EBS; REFERENCIA_CLIENTE_EBS)
                {
                }
                field(NOMBRE_CLIENTE; NOMBRE_CLIENTE)
                {
                }
                field(REGISTRO_CLIENTE; REGISTRO_CLIENTE)
                {
                }
                field(CAJA; CAJA)
                {
                }
                field(TIPO_PAGO; TIPO_PAGO)
                {
                }
                field(VALOR_VENTA_EXENTA; VALOR_VENTA_EXENTA)
                {
                }
                field(REB_DEV_VTA_EXENTA; REB_DEV_VTA_EXENTA)
                {
                }
                field(VALOR_VENTA_GRABADA; VALOR_VENTA_GRABADA)
                {
                }
                field(REB_DEV_VTA_GRABADA; REB_DEV_VTA_GRABADA)
                {
                }
                field(EFECTIVO_DOMICILIO_A_RECIBIR; EFECTIVO_DOMICILIO_A_RECIBIR)
                {
                }
                field(EFECTIVO_DOMICILIO_A_ENVIAR; EFECTIVO_DOMICILIO_A_ENVIAR)
                {
                }
                field(VALOR_IVA; VALOR_IVA)
                {
                }
                field(IVA_REB_DEV_VTA_GRABADA; IVA_REB_DEV_VTA_GRABADA)
                {
                }
                field(VALOR_CESC; xRec.VALOR_CESC)
                {
                }
                field(CESC_REB_DEV_VTA_GRABADA; xRec.CESC_REB_DEV_VTA_GRABADA)
                {
                }
                field(TOTAL; TOTAL)
                {
                }
                field(TOTAL_EFECTIVO; TOTAL_EFECTIVO)
                {
                }
                field(TOTAL_CREDITO; TOTAL_CREDITO)
                {
                }
                field(TARJETA1_ID; TARJETA1_ID)
                {
                }
                field(TARJETA1_VALOR; TARJETA1_VALOR)
                {
                }
                field(TARJETA2_ID; TARJETA2_ID)
                {
                }
                field(TARJETA2_VALOR; TARJETA2_VALOR)
                {
                }
                field(TARJETA3_ID; TARJETA3_ID)
                {
                }
                field(TARJETA3_VALOR; TARJETA3_VALOR)
                {
                }
                field(TARJETA4_ID; TARJETA4_ID)
                {
                }
                field(TARJETA4_VALOR; TARJETA4_VALOR)
                {
                }
                field(VALIDADO; VALIDADO)
                {
                }
                field(APLICADO_AR; APLICADO_AR)
                {
                }
                field(APLICADO_GL; APLICADO_GL)
                {
                }
                field(STATUS_GRAL; STATUS_GRAL)
                {
                }
                field(FECHA_DOC_ANULADO; FECHA_DOC_ANULADO)
                {
                }
                field(NUMERO_DOC_ANULADO; NUMERO_DOC_ANULADO)
                {
                }
                field(BATCH_SOURCE; BATCH_SOURCE)
                {
                }
                field(USUARIO; USUARIO)
                {
                }
                field(FECHA_REGISTRO; FECHA_REGISTRO)
                {
                }
                field(MOSTRAR; MOSTRAR)
                {
                }
                field(MONTO_RETENCION; MONTO_RETENCION)
                {
                }
                field(MONTO_PERCEPCION; MONTO_PERCEPCION)
                {
                }
                field(GIFTCARD; GIFTCARD)
                {
                }
            }
        }
    }

    actions
    {

        area(Processing)
        {
            action("Generar PITS Venta")
            {
                Image = Form;
                Promoted = true;
                PromotedCategory = Process;
                RunObject = page "FSN PITS On Demand";
            }

        }
    }
}

