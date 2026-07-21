codeunit 50058 "FSN Register PITS Sales"
{
    // CSMQ261115 Validacion para que reconozca y no repita registros
    // CSMQ141016 Cambios para mostrar el valor del CESC separado del valor del IVA
    // CSPNT141016 Redondeos CESC
    // CSALX20161221 A solicitud de Pedro Flores, valor debe ser bruto, sin impuestos
    // ITPF010817 Cambios para nuevo emisor de tarjeta de credito Promerica
    // ITPF190917 Agregar media de pago 5 Tarjeta VIP Agricola como tarjeta de Credito.
    // WVILLALTA27JUN19                      - New infocode EMISORES
    // WVILLALTA 09.21                       - Tender type = 21 in Ticket() Function in "Sale Is Return Sale"
    // FRODRIGUEZ07SEP21                     - Tender type 16,17  in Ticket() and Invoice() Function,
    // WVILLALTA 03.22                       - Bug fix, tender type 25
    // JH25052024 Conversion de CAL - AL
    // JH19072024 Se han reportado demasiados campos clave, se cambia get por setrange
    // JH19072024-1 Se traduce de nav a bc por un campo similar de "No. Serie Documento Devolucion" a "FSN Fiscal Serie Affected"

    trigger OnRun()
    begin
        ValidateBC;
        RowsAffected := 0;
        FillTable(0D, 0D, '');
    end;

    var
        TransHeader: Record "LSC Transaction Header";
        LASTTransHeader: Record "LSC Transaction Header";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
        TransPaymEntry: Record "LSC Trans. Payment Entry";
        TransInfocodeEntry: Record "LSC Trans. Infocode Entry";
        PITSSales: Record "FSN PITS_ventas";
        LASTTempPITSSales: Record "FSN PITS_ventas";
        LASTInsertPITSSales: Record "FSN PITS_ventas";
        POSTerminal: Record "LSC POS Terminal";
        NoSeriesLine: Record "No. Series Line";
        Customer: Record "Customer";
        Store: Record "LSC Store";
        DocumentType: Option Ticket,CreditoFiscal,ConsumidorFinal,NotaAbono;
        NoSeries: Record "No. Series";
        LineNo: Integer;
        ValorExento: Decimal;
        ValorGrabado: Decimal;
        ValorIVA: Decimal;
        ValorCESC: Decimal;
        ValorNetoDevEx: Decimal;
        ValorNetoDevGr: Decimal;
        ValorIVADev: Decimal;
        ValorCESCDev: Decimal;
        Total: Decimal;
        TotalEfectivo: Decimal;
        TotalCredito: Decimal;
        ATH: Decimal;
        CITI: Decimal;
        Credomatic: Decimal;
        Other: Decimal;
        EfectivoDomicilioARecibir: Decimal;
        EfectivoDomicilioAEnviar: Decimal;
        ValorRetencion: Decimal;
        ValorPercepcion: Decimal;
        RowsAffected: Integer;
        POSVATCode: Record "LSC POS VAT Code";
        POSVATCode18: Record "LSC POS VAT Code";
        InsertNew: Boolean;
        ActualDate: Date;
        MyNext: Decimal;
        MyDialog: Dialog;
        Incremento: Decimal;
        Promerica: Decimal;
        variable: Option;
        TotalPuntos: Decimal;
        gPOSCardEntry: Record "LSC POS Card Entry";
        gBinBank: Record "FSN BIN Bank";
        gInCardEntry: Boolean;
        gExtraData: Text[20];
        TotalGiftCard: Decimal;
        TotalHugoPay: Decimal;
        TotalBTC: Decimal;
        TransIncExpTmp: Record "LSC Trans. Inc./Exp. Entry" temporary;

    procedure FillTable(StartingDate: Date; EndingDate: Date; StoreNo: Code[10])
    var
        Text000: Label 'Procesando Registros... @1@@@@@';
    begin
        TransHeader.RESET;
        TransSalesEntry.RESET;
        TransPaymEntry.RESET;
        Store.RESET;
        POSTerminal.RESET;

        IF NOT POSVATCode.GET('IVA 13') THEN
            ERROR('No se ha establecido un valor para IVA 13');

        IF NOT POSVATCode18.GET('IVA 18') THEN                  //CSMQ141016
            ERROR('No se ha establecido un valor para IVA 18'); //CSMQ141016

        MyNext := 0;
        IF GUIALLOWED THEN
            MyDialog.OPEN(Text000, MyNext);

        //CSMQ290216 OnDemand****************************************
        IF (StartingDate <> 0D) AND (EndingDate <> 0D) THEN
            CLEAR(ActualDate)
        ELSE BEGIN
            //StartingDate := CALCDATE('<-1D>');  // CSALX20161220 Dia de seguridad
            //EndingDate := CALCDATE('<-1D>');    // CSALX20161220 Dia de seguridad
            StartingDate := CALCDATE('<-1D>');
            EndingDate := CALCDATE('<-2D>');
            PITSSales.RESET;
            PITSSales.SETRANGE(FECHA_DOCUMENTO, StartingDate, EndingDate);
            IF StoreNo <> '' THEN
                PITSSales.SETRANGE(SUCURSAL, StoreNo);
            PITSSales.DELETEALL;
            TransHeader.RESET;
            TransHeader.SETRANGE(Date, StartingDate, EndingDate);
            IF StoreNo <> '' THEN
                TransHeader.SETRANGE("Store No.", StoreNo);
            //TransHeader.MODIFYALL(Registered, FALSE); //JH29052024 Se comenta ya que se ejecutaran todos los registros
        END;
        //***********************************************************
        //TransHeader.SETRANGE("Posting Status", TransHeader."Posting Status"::Posted);
        TransHeader.SETRANGE("Posting Status", TransHeader."Posting Status"::" ", TransHeader."Posting Status"::Posted);
        //CSMQ290216 OnDemand

        FOR ActualDate := StartingDate TO EndingDate DO BEGIN
            TransHeader.SETRANGE(Date);
            TransHeader.SETRANGE(Date, ActualDate);
            //TransHeader.SetFilter("Receipt No.", '%1|%2', '0000PV#549000001876', '0000PV#549000001887');
            //if TransHeader.FindFirst() then
            //    Message('Encontrado');
            // variable:=TransHeader."Posting Status";
            //        MESSAGE('encontrado');
            IF StoreNo <> '' THEN BEGIN
                Store.SETRANGE("No.");
                Store.SETRANGE("No.", StoreNo);
                //   MESSAGE('encontrado');
            END;
            Incremento := 10000 / (Store.COUNT * (EndingDate - StartingDate + 1));
            IF Store.FIND('-') THEN
                REPEAT
                    TransHeader.SETRANGE("Store No.");    //Toma cada rango de tiendas
                    TransHeader.SETRANGE("Store No.", Store."No.");
                    POSTerminal.SETRANGE("Store No.");
                    POSTerminal.SETRANGE("Store No.", Store."No.");    //Setea solamente las POS Terminal de cada tienda
                                                                       //      MESSAGE('encontrado');
                    IF POSTerminal.FIND('-') THEN
                        REPEAT


                            TransHeader.SETRANGE("POS Terminal No.");
                            TransHeader.SETRANGE("POS Terminal No.", POSTerminal."No.");
                            //Tickets
                            ClearVariables();                                 //Limpia variables
                                                                              //JH29052024 Documento ya no se utiliza en BC
                                                                              //TransHeader.SETRANGE(FacturaExportacion); //

                            TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::Ticket);                //Reasigna filtro
                            Tickets('01TICKETS');

                            CLEAR(LASTTempPITSSales); //WVILLALTA 06.23-
                            CLEAR(LASTTransHeader);
                            CLEAR(LASTInsertPITSSales); //WVILLALTA 06.23+

                            //Factura Consumidor Final
                            //TransHeader.SETRANGE("FSN Document Type","FSN Document Type"::Ticket);
                            TransHeader.SetFilter("FSN Document Type", '<>%1', TransHeader."FSN Document Type"::Ticket);
                            TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::Factura);
                            Invoices('01CONSUMIDOR_FINAL');

                            //Factura Credito Fiscal
                            TransHeader.SetFilter("FSN Document Type", '<>%1', TransHeader."FSN Document Type"::Factura);
                            TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::"Credito Fiscal");
                            Invoices('01CREDITO_FISCAL');

                            //Nota de Credito (Nota de Abono [Devolucion])
                            TransHeader.SetFilter("FSN Document Type", '<>%1', TransHeader."FSN Document Type"::"Credito Fiscal");
                            TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::"Nota Credito");
                            Invoices('01NOTA_CREDITO');

                            //Factura Credito Fiscal
                            TransHeader.SetFilter("FSN Document Type", '<>%1', TransHeader."FSN Document Type"::"Nota Credito");
                            TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::"Devolucion Factura");
                            Invoices('01DOC_DEVOLUCION');

                        //Factura Exportacion //JH29052024 Documento ya no se utiliza en BC
                        //TransHeader.SETRANGE("FSN Document Type", TransHeader."FSN Document Type"::"Devolucion Factura");
                        //TransHeader.SETRANGE(FacturaExportacion); 
                        //Invoices('01FACT_EXPORTACION');

                        UNTIL POSTerminal.NEXT = 0;

                    IF GUIALLOWED THEN BEGIN
                        MyNext += Incremento;
                        MyDialog.UPDATE(1, ROUND(MyNext, 1, '<'));
                    END;
                UNTIL Store.NEXT = 0;

        END;
        IF GUIALLOWED THEN
            MyDialog.CLOSE();

        IF RowsAffected = 1 THEN
            MESSAGE('Proceso Finalizado\ registros insertados');
        /*
        ELSE
            MESSAGE('Proceso Finalizado\%1 registros insertados, ¿Ya se ejecutó antes?', RowsAffected);
        */
    end;

    procedure ClearVariables()
    begin
        ValorExento := 0;
        ValorGrabado := 0;
        ValorIVA := 0;
        ValorCESC := 0; //CSMQ141016
        ValorNetoDevEx := 0;
        ValorNetoDevGr := 0;
        ValorIVADev := 0;
        ValorCESCDev := 0;  //CSMQ141016
        Total := 0;
        TotalEfectivo := 0;
        TotalGiftCard := 0;
        TotalCredito := 0;
        TotalPuntos := 0;
        EfectivoDomicilioARecibir := 0;  //Nueva variable para el calculo de efectivo domicilio
        EfectivoDomicilioAEnviar := 0;  //Nueva variable para el calculo de efectivo domicilio
        ATH := 0;       //
        CITI := 0;      //  Nuevas variables para emisores
        Credomatic := 0;//
        Other := 0;     //
        Promerica := 0; //ITPF010817 Nueva variable para emisor Promerica
        ValorRetencion := 0;
        ValorPercepcion := 0;
        TotalHugoPay := 0;
        TotalBTC := 0;
        CLEAR(TransIncExpTmp);
        //InsertNew := FALSE;
    end;

    procedure Invoices(DocumentTypeLocal: Code[20])
    var
        LocalTransHeader: Record "LSC Transaction Header";
        IVAtemp: Decimal;
        IVAtdev: Decimal;
        TransIncomeExp_l: Record "LSC Trans. Inc./Exp. Entry";
        DTE: Record "FSN DTE TRansaction Header";
        Compress: Boolean;
        RefundTrans: Record "LSC Transaction Header";
    begin
        IF TransHeader.FIND('-') THEN
            //JH29052024 Se comenta ya que debe ejecutar todos los registros
            //IF NOT TransHeader.Registered THEN            //CSMQ261115 Validacion para que reconozca y no repita registros
                REPEAT
                    ClearVariables();
                    CLEAR(PITSSales);
                    PITSSales.INIT;
                    PITSSales.FECHA_DOCUMENTO := TransHeader.Date;
                    PITSSales.SUCURSAL := Store."No.";
                    PITSSales.TIPO_TRANSACCION := DocumentTypeLocal;
                    // MESSAGE('listo 2');
                    //PITSSales.SERIE_DOCUMENTO := ;
                    IF DocumentTypeLocal = '01DOC_DEVOLUCION' THEN BEGIN
                        LocalTransHeader.RESET;
                        LocalTransHeader.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                        LocalTransHeader.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                        LocalTransHeader.SETRANGE("Receipt No.", TransHeader."Retrieved from Receipt No.");
                        IF NOT LocalTransHeader.FINDFIRST THEN BEGIN
                            LocalTransHeader.SETRANGE("POS Terminal No.");
                            LocalTransHeader.SETRANGE(LocalTransHeader."Entry Status", 0);
                        END;
                        IF LocalTransHeader.FINDFIRST THEN BEGIN
                            // CSALX20161220 Preferentemente obtener numero de serie de TransactionHeader, agregado en esta fecha
                            //IF TransHeader."FSN NFC Affected" <> '' THEN BEGIN
                            //JH19072024-1 Se traduce de nav a bc por un campo similar de "No. Serie Documento Devolucion" a "FSN Fiscal Serie Affected"
                            IF LocalTransHeader."FSN Fiscal Serie Affected" <> '' THEN BEGIN
                                PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', LocalTransHeader."FSN Fiscal Serie Affected", LocalTransHeader."FSN Correlative");
                            END ELSE BEGIN
                                //CSMQ280316*****************************************************************************************************************
                                NoSeriesLine.RESET;
                                NoSeriesLine.SETRANGE("Series Code", LocalTransHeader."FSN No. Serie NCF");
                                //NoSeriesLine.SETRANGE(Open, TRUE);  //CSMQ180416    //CSMQ081116 Eliminacion de validacion de rango abierto
                                IF NoSeriesLine.FIND('+') THEN  //CSMQ081116 Encuentra el ultimo registro
                                    REPEAT
                                        IF ((LocalTransHeader."FSN Correlative" >= NoSeriesLine."Starting No.") AND (LocalTransHeader."FSN Correlative" <= NoSeriesLine."Ending No.")) THEN
                                            PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', NoSeriesLine."FSN Autorization", LocalTransHeader."FSN Correlative");
                                    UNTIL (NoSeriesLine.NEXT(-1) = 0) OR (PITSSales.SERIE_DOCUMENTO <> '');
                                //CSMQ081116 Recorre la tabla al reves
                                IF PITSSales.SERIE_DOCUMENTO = '' THEN
                                    PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', LocalTransHeader."FSN No. Serie NCF", LocalTransHeader."FSN Correlative");
                                //CSMQ280316*****************************************************************************************************************
                            END;

                            //PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', LocalTransHeader."FSN No. Serie NCF", LocalTransHeader."Correlativo Facturas");     //CSMQ280316
                            PITSSales.NCF := LocalTransHeader."FSN Correlative"; //CSMQ070316 Columna extra para NCF
                        END;
                    END ELSE BEGIN
                        // CSALX20161220 Preferentemente obtener numero de serie de TransactionHeader, agregado en esta fecha
                        IF TransHeader."FSN Fiscal Serie Affected" <> '' THEN BEGIN
                            PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN Fiscal Serie Affected", TransHeader."FSN Correlative");
                        END ELSE BEGIN
                            //CSMQ280316*****************************************************************************************************************
                            NoSeriesLine.RESET;
                            NoSeriesLine.SETRANGE("Series Code", TransHeader."FSN No. Serie NCF");
                            //NoSeriesLine.SETRANGE(Open, TRUE);  //CSMQ180416    //CSMQ081116 Eliminacion de validacion de rango abierto
                            IF NoSeriesLine.FIND('+') THEN  //CSMQ081116 Encuentra el ultimo registro
                                REPEAT
                                    IF ((TransHeader."FSN Correlative" >= NoSeriesLine."Starting No.") AND (TransHeader."FSN Correlative" <= NoSeriesLine."Ending No.")) THEN
                                        PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', NoSeriesLine."FSN Autorization", TransHeader."FSN Correlative");
                                UNTIL (NoSeriesLine.NEXT(-1) = 0) OR (PITSSales.SERIE_DOCUMENTO <> '');
                            //CSMQ081116 Recorre la tabla al reves
                            IF PITSSales.SERIE_DOCUMENTO = '' THEN
                                PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN Correlative");
                            //CSMQ280316*****************************************************************************************************************
                        END;

                        //PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."Correlativo Facturas");   //CSMQ280316
                        PITSSales.NCF := TransHeader."FSN Correlative";  //CSMQ070316 Columna extra para NCF
                    END;
                    PITSSales.CODIGO_CLIENTE := DELCHR(TransHeader."Customer No.", '13', '');
                    //PITSSales.NOMBRE_CLIENTE := TransHeader."Razon Social"; //No seria mejor nombre?
                    PITSSales.REGISTRO_CLIENTE := DELCHR(TransHeader."FSN NRC", '13', '');
                    IF Customer.GET(TransHeader."Customer No.") THEN BEGIN
                        PITSSales.REFERENCIA_CLIENTE_EBS := DELCHR(Customer."FSN EBS Reference", '13', '');
                        PITSSales.NOMBRE_CLIENTE := DELCHR(Customer.Name, '13', '');  //CSMQ020316 Nueva forma de obtener el nombre
                        IF TransHeader."FSN NRC" = '' THEN                //CSMQ060416 Nueva forma de obtener el NRC
                            PITSSales.REGISTRO_CLIENTE := DELCHR(Customer."FSN NRC", '13', '');
                    END;
                    //********************************************************************************
                    PITSSales.CAJA := TransHeader."POS Terminal No.";
                    PITSSales.MONTO_RETENCION := TransHeader."FSN Retention Amount";
                    PITSSales.MONTO_PERCEPCION := TransHeader."FSN Perception Amount";
                    PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard

                    //Quizas deberia ser aqui
                    //CSMQ070316 Probemos*******************************************************************
                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                    IF TransSalesEntry.ISEMPTY THEN BEGIN
                        TransInfocodeEntry.RESET;
                        TransInfocodeEntry.SETRANGE("Store No.", TransHeader."Store No.");
                        TransInfocodeEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");
                        TransInfocodeEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                        TransInfocodeEntry.SETRANGE("Transaction Type", TransInfocodeEntry."Transaction Type"::"Income/Expense Entry");
                        TransInfocodeEntry.SETRANGE(Infocode, 'SUCDESTINO');
                        IF TransInfocodeEntry.FIND('-') THEN
                            REPEAT
                                EfectivoDomicilioAEnviar += (TransInfocodeEntry.Amount * -1);
                            UNTIL TransInfocodeEntry.NEXT = 0;
                    END;
                    //**************************************************************************************

                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 0');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            //CSMQ180216 Nuevo
                            IF TransSalesEntry."Total Rounded Amt." > 0 THEN
                                ValorNetoDevEx += TransSalesEntry."Total Rounded Amt."
                            ELSE
                                ValorExento += (TransSalesEntry."Total Rounded Amt." * -1);
                        UNTIL TransSalesEntry.NEXT = 0;
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 13');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            //CSMQ180216 Nuevo
                            IF (TransSalesEntry."Total Rounded Amt." > 0) AND (TransSalesEntry."Item No." <> 'A1864') AND (TransSalesEntry."Item No." <> 'A1871') AND (TransSalesEntry."Item No." <> 'A100265') THEN BEGIN
                                ValorNetoDevGr += TransSalesEntry."Total Rounded Amt."; // CSALX20161221
                                                                                        //ValorNetoDevGr += TransSalesEntry."Net Amount";
                                ValorIVADev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);  //CSMQ070316 Cambio para q siempre
                            END                                                                                                                             //aparezca IVADev en la columna IVA
                            ELSE BEGIN
                                ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1); // CSALX20161221
                                                                                             //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                            END;
                        UNTIL TransSalesEntry.NEXT = 0;
                    //CSMQ141016-
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 18');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            IF (TransSalesEntry."Total Rounded Amt." > 0) AND (TransSalesEntry."Item No." <> 'A1864') AND (TransSalesEntry."Item No." <> 'A1871') AND (TransSalesEntry."Item No." <> 'A100265') THEN BEGIN
                                ValorNetoDevGr += TransSalesEntry."Total Rounded Amt."; // CSALX20161221
                                ValorNetoDevGr += TransSalesEntry."Net Amount";
                                ValorIVADev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);  //CSMQ070316 Cambio para q siempre
                                IVAtemp := (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                                IVAtdev := ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                //aparezca IVADev en la columna IVA
                                //CSPNT141016ValorCESCDev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100));
                                //ValorCESC += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1);
                                //CSALX20161220 Siguientes dos lineas comentadas y reemplazadas para obtener el valor del CESC por diferencia para reducir diferencias de centavos
                                //ValorCESCDev += ROUND(ROUND(TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100)),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100),0.01);
                                //ValorCESC += ROUND(((ROUND(TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100)),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1),0.01);
                                ValorCESCDev += (TransSalesEntry."VAT Amount" - IVAtdev);
                                ValorCESC += ((TransSalesEntry."VAT Amount" * -1) - IVAtemp);
                            END
                            ELSE BEGIN
                                ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1); // CSALX20161221
                                                                                             //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                                IVAtemp := (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);

                                //CSPNT141016ValorCESC += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1);
                                //CSALX20161220 Siguiente linea comentada y reemplazada para obtener el valor del CESC por diferencia para reducir diferencias de centavos
                                //ValorCESC += ROUND(((ROUND(TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100)),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1),0.01);
                                ValorCESC += ((TransSalesEntry."VAT Amount" * -1) - IVAtemp);
                            END;
                        UNTIL TransSalesEntry.NEXT = 0;
                    //CSMQ141016+
                    Total += (TransHeader."Gross Amount" * -1);
                    //Total += ValorExento + ValorGrabado;
                    TransPaymEntry.RESET;
                    TransPaymEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    IF TransPaymEntry.FIND('-') AND NOT TransSalesEntry.ISEMPTY THEN
                        REPEAT
                            IF ((TransPaymEntry."Tender Type" = '1') OR (TransPaymEntry."Tender Type" = '2') OR (TransPaymEntry."Tender Type" = '8')) THEN   //ITFSNPF10122016 Agrega Media de pago 8 para Vales $15
                                TotalEfectivo += TransPaymEntry."Amount Tendered"
                            ELSE
                                IF (TransPaymEntry."Tender Type" = '4') THEN
                                    TotalCredito += TransPaymEntry."Amount Tendered"
                                ELSE
                                    IF TransPaymEntry."Tender Type" = '21' THEN              //CSMQ070316
                                        EfectivoDomicilioARecibir += TransPaymEntry."Amount Tendered"  //Calculo Efectivo Domicilio
                                    ELSE
                                        IF TransPaymEntry."Tender Type" = '25' THEN //ITPF26032021
                                            TotalGiftCard += TransPaymEntry."Amount Tendered"
                                        ELSE
                                            IF TransPaymEntry."Tender Type" = '17' THEN //FRODRIGUEZ07JUN21
                                                TotalHugoPay += TransPaymEntry."Amount Tendered"
                                            ELSE
                                                IF TransPaymEntry."Tender Type" = '16' THEN//FRODRIGUEZ07JUN21
                                                    TotalBTC += TransPaymEntry."Amount Tendered"


                                                ELSE
                                                    IF TransPaymEntry."Tender Type" = '11' THEN // ITPF111018
                                                        TotalPuntos += TransPaymEntry."Amount Tendered"  // Calculo de Total De Puntos Utilizados
                                                    ELSE BEGIN
                                                        IF (TransPaymEntry."Tender Type" = '20') OR (TransPaymEntry."Tender Type" = '5') THEN BEGIN //ITPF190917
                                                            gExtraData := '';
                                                            gInCardEntry := FALSE;
                                                            //JH29052024 Se modifica el get por setrange, la clave primaria de la tabla se a cambiado en BC
                                                            //IF gPOSCardEntry.GET(TransPaymEntry."Store No.", TransPaymEntry."POS Terminal No.", TransPaymEntry."Receipt No.", TransPaymEntry."Line No.") THEN BEGIN
                                                            gPOSCardEntry.Reset();
                                                            gPOSCardEntry.SetRange("Store No.", TransPaymEntry."Store No.");
                                                            gPOSCardEntry.SetRange("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                            gPOSCardEntry.SetRange("Receipt No.", TransPaymEntry."Receipt No.");
                                                            gPOSCardEntry.SetRange("Line No.", TransPaymEntry."Line No.");
                                                            if gPOSCardEntry.FindFirst() then begin
                                                                repeat
                                                                    gInCardEntry := TRUE;
                                                                    IF gPOSCardEntry."Extra Data" <> '' THEN
                                                                        gExtraData := gPOSCardEntry."Extra Data"
                                                                    ELSE
                                                                        IF gBinBank.GET(gPOSCardEntry."FSN BIN No.") THEN
                                                                            IF gBinBank."Extra Data" <> '' THEN
                                                                                gExtraData := gBinBank."Extra Data";
                                                                until gPOSCardEntry.Next() = 0;
                                                            end;

                                                        END;
                                                        IF gInCardEntry THEN
                                                            CASE gExtraData OF
                                                                'ATH':
                                                                    BEGIN
                                                                        PITSSales.TARJETA1_ID := gExtraData;
                                                                        PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                'CITI':
                                                                    BEGIN
                                                                        PITSSales.TARJETA2_ID := gExtraData;
                                                                        PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                'CREDOMATIC':
                                                                    BEGIN
                                                                        PITSSales.TARJETA3_ID := gExtraData;
                                                                        PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                ELSE BEGIN
                                                                    PITSSales.TARJETA1_ID := 'ATH';
                                                                    PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                END;
                                                            END;

                                                        IF NOT gInCardEntry THEN BEGIN  //WVILLALTA27JUL19+

                                                            // TotalCredito += TransPaymEntry."Amount Tendered";   //
                                                            TransInfocodeEntry.RESET;
                                                            //WVILLALTA27JUN19-
                                                            TransInfocodeEntry.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Transaction Type", "Line No.", Infocode, "Entry Line No.");
                                                            //WVILLALTA27JUN19+
                                                            TransInfocodeEntry.SETRANGE("Store No.", TransPaymEntry."Store No.");
                                                            TransInfocodeEntry.SETRANGE("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                            TransInfocodeEntry.SETRANGE("Transaction No.", TransPaymEntry."Transaction No.");
                                                            TransInfocodeEntry.SETRANGE("Transaction Type", TransInfocodeEntry."Transaction Type"::"Payment Entry");
                                                            TransInfocodeEntry.SETRANGE("Line No.", TransPaymEntry."Line No.");
                                                            TransInfocodeEntry.SETRANGE(Infocode, 'TIPOTARJET');
                                                            IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                //Orden de emisores: 1.ATH 2.CITI 3.CREDOMATIC
                                                                CASE TransInfocodeEntry.Information OF
                                                                    'ATH':
                                                                        BEGIN
                                                                            PITSSales.TARJETA1_ID := TransInfocodeEntry.Information;
                                                                            PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CITI':
                                                                        BEGIN
                                                                            PITSSales.TARJETA2_ID := TransInfocodeEntry.Information;
                                                                            PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CREDOMATIC':
                                                                        BEGIN
                                                                            PITSSales.TARJETA3_ID := TransInfocodeEntry.Information;
                                                                            PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    //'PROMERICA': BEGIN      //ITPF010817 //Delete by WVILLALTA27JUN19
                                                                    ELSE BEGIN
                                                                        //PITSSales.TARJETA4_ID := TransInfocodeEntry.Information;
                                                                        PITSSales.TARJETA1_ID := 'ATH';
                                                                        PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                    END;

                                                                /*
                                                                ELSE BEGIN
                                                                  PITSSales.TARJETA4_ID := 'Other';
                                                                  PITSSales.TARJETA4_VALOR += TransPaymEntry."Amount Tendered";
                                                                END;
                                                                *///WVILLALTA27JUN19 Clear exception
                                                                END;
                                                            END
                                                            ELSE BEGIN
                                                                //WVILLALTA27JUN19-
                                                                TransInfocodeEntry.SETRANGE(Infocode, 'EMISORES');
                                                                IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                    CASE TransInfocodeEntry.Information OF
                                                                        'ATH', 'AGRICOLA', 'SCOTIABANK':
                                                                            BEGIN
                                                                                PITSSales.TARJETA1_ID := 'ATH';
                                                                                PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CITI':
                                                                            BEGIN
                                                                                PITSSales.TARJETA2_ID := 'CITI';
                                                                                PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CREDOMATIC', 'BAC CREDOMATIC':
                                                                            BEGIN
                                                                                PITSSales.TARJETA3_ID := 'CREDOMATIC';
                                                                                PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        ELSE BEGIN
                                                                            //PITSSales.TARJETA4_ID := TransInfocodeEntry.Information;
                                                                            PITSSales.TARJETA1_ID := 'ATH';
                                                                            PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    END;
                                                                END ELSE BEGIN
                                                                    //All Exception
                                                                    PITSSales.TARJETA1_ID := 'ATH';
                                                                    PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                END;
                                                                //WVILLALTA27JUN19+
                                                            END;
                                                        END;//WVILLALTA27JUL19+
                                                    END;
                        //END;
                        UNTIL TransPaymEntry.NEXT = 0;

                    //  ***********************************Tipos de pago**************************//  //
                    //                                                                                //
                    //  NA (No Aplica [Para devoluciones])                                            //
                    //  MX (Mixto)                                                                    //
                    //  EF (Solo efectivo)                                                            //
                    //  CR (Solo credito)                                                             //
                    //  VD (Voided [Transaccion anulada])                                             //
                    //
                    IF (TransHeader."POS Terminal No." = 'PV#369') AND (TransHeader."Customer No." = 'PV#216C34386') THEN
                        TransHeader."POS Terminal No." := TransHeader."POS Terminal No.";
                    //
                    IF (DocumentTypeLocal = '01DOC_DEVOLUCION') OR (DocumentTypeLocal = '01NOTA_CREDITO') THEN
                        PITSSales.TIPO_PAGO := 'NA'
                    ELSE
                        IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito <> 0) THEN  //FRODRIGUEZ07SEP21
                            PITSSales.TIPO_PAGO := 'MX'
                        ELSE
                            IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito = 0) THEN //FRODRIGUEZ07SEP21
                                PITSSales.TIPO_PAGO := 'EF'
                            ELSE
                                IF (TotalEfectivo = 0) AND ((TotalCredito <> 0) OR (ATH <> 0) OR (CITI <> 0) OR (Credomatic <> 0) OR (Other <> 0) OR (Promerica <> 0)
                                OR (PITSSales.TARJETA1_VALOR <> 0) OR (PITSSales.TARJETA2_VALOR <> 0) OR (PITSSales.TARJETA3_VALOR <> 0) OR (PITSSales.TARJETA4_VALOR <> 0)
                                OR (PITSSales.TOTAL_CREDITO <> 0)
                                ) THEN //ITPF010817
                                    PITSSales.TIPO_PAGO := 'CR'
                                ELSE
                                    PITSSales.TIPO_PAGO := 'VD';

                    PITSSales.VALOR_VENTA_EXENTA := ValorExento;
                    PITSSales.VALOR_VENTA_GRABADA := ValorGrabado;
                    PITSSales.VALOR_IVA := ValorIVA;
                    PITSSales.VALOR_CESC := ValorCESC;  //CSMQ141016
                                                        //CSMQ180216 Nuevas******************************
                    PITSSales.REB_DEV_VTA_EXENTA := ValorNetoDevEx;
                    PITSSales.REB_DEV_VTA_GRABADA := ValorNetoDevGr;
                    PITSSales.IVA_REB_DEV_VTA_GRABADA := ValorIVADev;
                    PITSSales.CESC_REB_DEV_VTA_GRABADA := ValorCESCDev; //CSMQ141016
                                                                        //***********************************************
                    PITSSales.TOTAL := Total;
                    PITSSales.TOTAL_EFECTIVO := TotalEfectivo + EfectivoDomicilioARecibir;
                    PITSSales.TOTAL_CREDITO := TotalCredito;
                    PITSSales.EFECTIVO_DOMICILIO_A_RECIBIR := EfectivoDomicilioARecibir;  //CSMQ070316 Nuevas Variables
                    PITSSales.EFECTIVO_DOMICILIO_A_ENVIAR := EfectivoDomicilioAEnviar;
                    PITSSales.TOTAL_PUNTOS := TotalPuntos;  //ITPF11102018 Nuevo Campo para total de puntos
                    PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard

                    //WVILLATA INC. EXP.-
                    IF TransHeader."Income/Exp. Amount" <> 0 THEN BEGIN
                        TransIncomeExp_l.RESET;
                        TransIncomeExp_l.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");

                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Store No.", TransHeader."Store No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."POS Terminal No.", TransHeader."POS Terminal No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Transaction No.", TransHeader."Transaction No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."No.", '12');
                        TransIncomeExp_l.CALCSUMS(TransIncomeExp_l."Net Amount", TransIncomeExp_l."VAT Amount");

                        PITSSales.VALOR_VENTA_GRABADA -= (TransIncomeExp_l."Net Amount" + TransIncomeExp_l."VAT Amount");
                        PITSSales.VALOR_IVA -= TransIncomeExp_l."VAT Amount";
                        PITSSales.TOTAL -= (TransIncomeExp_l."Net Amount" + TransIncomeExp_l."VAT Amount");
                    END;
                    //WVILLATA INC. EXP.+


                    //WVILLALTA 05.23-
                    IF DTE.GET(TransHeader."Store No.", TransHeader."POS Terminal No.", TransHeader."Transaction No.") THEN BEGIN
                        PITSSales.DTE := TRUE;
                        PITSSales.SERIE_DOCUMENTO := DTE."DTE Invoice";
                        PITSSales.DTE_CODIGO_GENERACION_INICIO := DTE."DTE AuthNumber";
                        PITSSales.DTE_CODIGO_GENERACION_FINAL := DTE."DTE AuthNumber";
                        PITSSales.DTE_CODIGO_CONTROL := DTE."DTE Invoice";

                        PITSSales.DOCUMENTO_INICIAL := DTE."DTE Invoice";
                        PITSSales.DOCUMENTO_FINAL := DTE."DTE Invoice";
                    END;
                    //WVILLALTA 05.23+

                    PITSSales.HUGO_PAY := TotalHugoPay; //FRODRIGUEZ07SEP21
                    PITSSales.BITCOIN := TotalBTC; //FRODRIGUEZ07SEP21


                    //WVILLALTA 05.23- Compresión de registros facturas
                    LASTTempPITSSales := PITSSales;
                    Compress := FALSE;
                    IF (TransHeader."FSN Document Type" = TransHeader."FSN Document Type"::Factura) AND (LASTInsertPITSSales.CAJA <> '') AND PITSSales.DTE AND LASTInsertPITSSales.DTE THEN BEGIN

                        IF (LASTTempPITSSales.TOTAL_CREDITO <> 0) OR (LASTInsertPITSSales.TOTAL_CREDITO <> 0) OR
                          (TransHeader."Refund Receipt No." <> '') OR (TransHeader."Retrieved from Receipt No." <> '')
                          OR TransHeader."Sale Is Return Sale" OR (LASTTransHeader."Refund Receipt No." <> '')

                        THEN
                            Compress := FALSE
                        ELSE BEGIN
                            Compress := CompressInvoice(LASTTempPITSSales, LASTInsertPITSSales);
                        END;

                    END;

                    IF NOT Compress THEN BEGIN
                        IF NOT PITSSales.DTE THEN
                            IF (TransHeader."FSN Document Type"::Factura = TransHeader."FSN Document Type") OR (TransHeader."FSN Document Type" = TransHeader."FSN Document Type"::"Credito Fiscal") OR (TransHeader."FSN Document Type" = TransHeader."FSN Document Type"::"Nota Credito") THEN
                                IF TransHeader.Date >= DMY2DATE(28, 6, 2023) THEN
                                    IF (TransHeader."FSN Fiscal Serie Affected" = '') AND (STRLEN(TransHeader."FSN NCF") >= 14) THEN
                                        PITSSales.DTE := TRUE;

                        /*  IF PITSSales.DTE THEN
                            IF (TransHeader."Refund Receipt No." <> '') AND (PITSSales.DTE_CODIGO_GENERACION_INICIO = '') THEN BEGIN //WVILLALTA 07.23-
                              RefundTrans.RESET;
                              RefundTrans.SETRANGE(RefundTrans."Receipt No.",TransHeader."Receipt No.");
                              RefundTrans.SETRANGE(RefundTrans."Entry Status",0);
                              IF RefundTrans.FIND('-') THEN
                                PITSSales.ANULADO := TRUE;
                            END;
                          IF PITSSales.DTE THEN
                            IF TransHeader.NotaCredito THEN BEGIN
                              RefundTrans.RESET;
                              RefundTrans.SETRANGE(RefundTrans."Receipt No.",TransHeader."Retrieved from Receipt No.");
                              RefundTrans.SETRANGE(RefundTrans."Entry Status",0);
                              IF RefundTrans.FIND('-') AND (STRLEN(RefundTrans.NCF) >= 14) AND (RefundTrans.Date >= DMY2DATE(28,6,2023)) THEN
                                IF NOT DTE.GET(RefundTrans."Store No.",RefundTrans."POS Terminal No.",RefundTrans."Transaction No.") THEN
                                  PITSSales.ANULADO := TRUE;
                            END;                                                                                                    //WVILLALTA 07.23+
                          IF TransHeader."Doc. Devolucion" THEN BEGIN
                            RefundTrans.RESET;
                            RefundTrans.SETRANGE(RefundTrans."Receipt No.",TransHeader."Retrieved from Receipt No.");
                            RefundTrans.SETRANGE(RefundTrans."Entry Status",0);
                            IF RefundTrans.FIND('-') AND (STRLEN(RefundTrans.NCF) >= 14) AND (RefundTrans.Date >= DMY2DATE(28,6,2023)) THEN
                              IF NOT DTE.GET(RefundTrans."Store No.",RefundTrans."POS Terminal No.",RefundTrans."Transaction No.") THEN
                                  PITSSales.ANULADO := TRUE
                          END;*/

                        PITSSales.INSERT(TRUE);

                        LASTInsertPITSSales := PITSSales;
                        LASTTransHeader := TransHeader;
                        RowsAffected += 1;
                    END;
                    //WVILLALTA 05.23-
                    //PITSSales.INSERT(TRUE);


                    //TransHeader.Registered := TRUE; //JH29052024 Se comenta se procesaran todos los registros
                    TransHeader.MODIFY;
            UNTIL TransHeader.NEXT = 0;

    end;

    procedure Tickets(DocumentTypeLocal: Code[20])
    var
        LocalTransHeader: Record "LSC Transaction Header";
        IVAtemp: Decimal;
        IVAtdev: Decimal;
        P: Integer;
        TransIncomeExp_l: Record "LSC Trans. Inc./Exp. Entry";
    begin
        InsertNew := TRUE;
        IF TransHeader.FIND('-') THEN BEGIN
            /* JH29052024 Se comenta, se procesaran todos los registros
            WHILE TransHeader.Registered DO BEGIN  //CSMQ26
            1115 Validacion para que reconozca y no repita registros
                IF TransHeader.NEXT = 0 THEN
                    EXIT;
            END;
            */
            REPEAT
                //JH29052024 Se comenta se procesaran todos los registros
                //IF NOT TransHeader.Registered THEN BEGIN       //CSMQ261115 Validacion para que reconozca y no repita registros

                IF TransHeader."Sale Is Return Sale" OR (TransHeader."Amount to Account" <> 0) THEN BEGIN //Si es devolucion

                    IF Total <> 0 THEN BEGIN  //Si hay datos previos insertarlos porque la siguiente sera una nueva linea
                        TransHeader.NEXT(-1);

                        //  ***********************************Tipos de pago**************************//  //
                        //                                                                                //
                        //  MX (Mixto)                                                                    //
                        //  EF (Solo efectivo)                                                            //
                        //  CR (Solo credito)                                                             //
                        //  VD (Voided [Transacciones anulada])                                             //
                        //                                                                                //
                        IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito <> 0) THEN  //FRODRIGUEZ07SEP21
                            PITSSales.TIPO_PAGO := 'MX'
                        ELSE
                            IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito = 0) THEN //FRODRIGUEZ07SEP21
                                PITSSales.TIPO_PAGO := 'EF'
                            ELSE
                                IF (TotalEfectivo = 0) AND ((TotalCredito <> 0) OR (ATH <> 0) OR (CITI <> 0) OR (Credomatic <> 0) OR (Other <> 0) OR (Promerica <> 0)
                                OR (PITSSales.TARJETA1_VALOR <> 0) OR (PITSSales.TARJETA2_VALOR <> 0) OR (PITSSales.TARJETA3_VALOR <> 0) OR (PITSSales.TARJETA4_VALOR <> 0)
                                OR (PITSSales.TOTAL_CREDITO <> 0)
                                ) THEN    //ITPF010817
                                    PITSSales.TIPO_PAGO := 'CR'
                                ELSE
                                    PITSSales.TIPO_PAGO := 'VD';
                        IF TransHeader."FSN NCF" <> '' THEN                                                                     //03.23-
                            PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");//03.23+                                                                                                                                //
                                                                                                                                     //PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader.NCF);   //MAS
                        PITSSales.VALOR_VENTA_EXENTA := ValorExento;                     //
                        PITSSales.VALOR_VENTA_GRABADA := ValorGrabado;                   //  COSAS
                        PITSSales.VALOR_IVA := ValorIVA;                                 //
                        PITSSales.VALOR_CESC := ValorCESC;  //CSMQ141016
                                                            //CSMQ180216 Nuevas******************************
                        PITSSales.REB_DEV_VTA_EXENTA := ValorNetoDevEx;
                        PITSSales.REB_DEV_VTA_GRABADA := ValorNetoDevGr;
                        PITSSales.IVA_REB_DEV_VTA_GRABADA := ValorIVADev;
                        PITSSales.CESC_REB_DEV_VTA_GRABADA := ValorCESCDev; //CSMQ141016
                                                                            //***********************************************
                                                                            //CSMQ240216 Tarjetas de Credito*****************
                        PITSSales.TARJETA1_VALOR := ATH;
                        PITSSales.TARJETA2_VALOR := CITI;
                        PITSSales.TARJETA3_VALOR := Credomatic;
                        //PITSSales.TARJETA4_VALOR := Other;
                        PITSSales.TARJETA4_VALOR := Promerica;  //ITPF010817

                        //***********************************************

                        PITSSales.TOTAL := Total;                                        //   EN
                        PITSSales.TOTAL_EFECTIVO := TotalEfectivo + EfectivoDomicilioARecibir;                       //
                        PITSSales.TOTAL_CREDITO := TotalCredito;                         //  COMUN
                        PITSSales.MONTO_RETENCION := ValorRetencion;
                        PITSSales.MONTO_PERCEPCION := ValorPercepcion;
                        PITSSales.EFECTIVO_DOMICILIO_A_RECIBIR := EfectivoDomicilioARecibir;  //CSMQ070316 Nuevas Variables
                        PITSSales.EFECTIVO_DOMICILIO_A_ENVIAR := EfectivoDomicilioAEnviar;
                        PITSSales.TOTAL_PUNTOS := TotalPuntos;  //ITPF11102018 Nuevo Campo para total de puntos
                        PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard
                        PITSSales.HUGO_PAY := TotalHugoPay; //FRODRIGUEZ07SEP21
                        PITSSales.BITCOIN := TotalBTC; //FRODRIGUEZ07SEP21

                        //WVILLATA INC. EXP.-
                        IF TransIncExpTmp."Net Amount" <> 0 THEN BEGIN
                            /*TransIncomeExp_l.RESET;
                            TransIncomeExp_l.SETCURRENTKEY("Store No.","POS Terminal No.","Transaction No.","Line No.");

                            TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Store No.",TransHeader."Store No.");
                            TransIncomeExp_l.SETRANGE(TransIncomeExp_l."POS Terminal No.",TransHeader."POS Terminal No.");
                            TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Transaction No.",TransHeader."Transaction No.");
                            TransIncomeExp_l.SETRANGE(TransIncomeExp_l."No.",'12');
                            TransIncomeExp_l.CALCSUMS(TransIncomeExp_l."Net Amount",TransIncomeExp_l."VAT Amount");
                            */
                            PITSSales.VALOR_VENTA_GRABADA -= (TransIncExpTmp."Net Amount" + TransIncExpTmp."VAT Amount");
                            PITSSales.VALOR_IVA -= TransIncExpTmp."VAT Amount";
                            PITSSales.TOTAL -= (TransIncExpTmp."Net Amount" + TransIncExpTmp."VAT Amount");
                        END;
                        //WVILLATA INC. EXP.+


                        PITSSales.INSERT(TRUE);
                        RowsAffected += 1;                                               //
                        TransHeader.NEXT;
                    END;
                    //******************Limpiar Variables
                    ClearVariables;
                    //***************************************************************************************
                    //Inicializar nueva linea
                    CLEAR(PITSSales);
                    PITSSales.INIT;                                                  //  COSAS
                    PITSSales.FECHA_DOCUMENTO := TransHeader.Date;                   //
                    PITSSales.SUCURSAL := Store."No.";                               //   EN
                    IF TransHeader."Sale Is Return Sale" THEN
                        PITSSales.TIPO_TRANSACCION := '01NOTA_ABONO'

                    ELSE
                        PITSSales.TIPO_TRANSACCION := DocumentTypeLocal;                //

                    PITSSales.NCF := TransHeader."FSN NCF"; //CSMQ070316 Nueva columna para NCF
                    PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");

                    IF TransHeader."FSN NCF" <> '' THEN                                                                     //03.23-
                        PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");
                    IF PITSSales.DOCUMENTO_INICIAL = '' THEN
                        PITSSales.DOCUMENTO_INICIAL := PITSSales.DOCUMENTO_FINAL;                                       //03.23+

                    //PITSSales.DOCUMENTO_INICIAL := TransHeader.NCF;                //
                    PITSSales.CODIGO_CLIENTE := TransHeader."Customer No.";
                    //PITSSales.NOMBRE_CLIENTE := TransHeader."Razon Social";                   //                 pendiente
                    PITSSales.REGISTRO_CLIENTE := TransHeader."FSN NRC";                       // TICKETS

                    IF Customer.GET(TransHeader."Customer No.") THEN BEGIN
                        PITSSales.REFERENCIA_CLIENTE_EBS := Customer."FSN EBS Reference";
                        PITSSales.NOMBRE_CLIENTE := Customer.Name;  //CSMQ020316 Nueva forma de obtener el nombre
                        IF TransHeader."FSN NRC" = '' THEN                //CSMQ060416 Nueva forma de obtener el NRC
                            PITSSales.REGISTRO_CLIENTE := Customer."FSN NRC";
                    END;
                    PITSSales.CAJA := TransHeader."POS Terminal No.";                //
                    PITSSales.MONTO_RETENCION := TransHeader."FSN Retention Amount";
                    PITSSales.MONTO_PERCEPCION := TransHeader."FSN Perception Amount";

                    //PITSSales.TIPO_PAGO := 'YV';   //Revisar                         //

                    //Proceso de calculo para devolucion de ticket********************************************
                    //O cargo a cuenta************************************************************************ CSMQ230216
                    //****************************************************************************************
                    TransSalesEntry.Reset();
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                    //Exento
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 0');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            IF TransHeader."Sale Is Return Sale" THEN  //CSMQ230216 Devolucion o Credito
                                ValorNetoDevEx += TransSalesEntry."Total Rounded Amt."
                            ELSE
                                ValorExento += (TransSalesEntry."Total Rounded Amt." * -1); //CSMQ260716
                        UNTIL TransSalesEntry.NEXT = 0;
                    //Grabado
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 13');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            IF TransHeader."Sale Is Return Sale" THEN BEGIN  //CSMQ230216 Devolucion o Credito
                                ValorNetoDevGr += TransSalesEntry."Total Rounded Amt."; // CSALX20161221
                                                                                        //ValorNetoDevGr += TransSalesEntry."Net Amount";
                                ValorIVADev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);  //CSMQ070316 Cambio para q aparezca
                            END                                                                                                                             //IVADev en la columna IVA
                            ELSE BEGIN
                                ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1); // CSALX20161221
                                                                                             //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                            END;
                        //ValorIVA += (ValorIVADev * -1);
                        UNTIL TransSalesEntry.NEXT = 0;
                    //CSMQ141016-
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 18');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            IF TransSalesEntry."Total Rounded Amt." > 0 THEN BEGIN
                                ValorNetoDevGr += TransSalesEntry."Total Rounded Amt."; // CSALX20161221

                                //ValorNetoDevGr += TransSalesEntry."Net Amount";
                                ValorIVADev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);  //CSMQ070316 Cambio para q siempre
                                IVAtemp := (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                                IVAtdev := ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100));
                                //aparezca IVADev en la columna IVA
                                //CSPNT141016ValorCESCDev += ((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100));
                                //ValorCESC += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1);
                                //CSALX20161220 Siguientes dos lineas comentadas y reemplazadas para obtener el valor del CESC por diferencia para reducir diferencias de centavos
                                //ValorCESCDev += ROUND((ROUND((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)),0.01);
                                //ValorCESC += ROUND(((ROUND((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1),0.01);
                                ValorCESCDev += (TransSalesEntry."VAT Amount" - IVAtdev);
                                ValorCESC += ((TransSalesEntry."VAT Amount" * -1) - IVAtemp);
                            END ELSE BEGIN
                                ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1);  // CSALX20161221
                                                                                              //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                                ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                                IVAtemp := (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);

                                //CSPNT141016ValorCESC += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1);
                                //CSALX20161220 Siguientes dos lineas comentadas y reemplazadas para obtener el valor del CESC por diferencia para reducir diferencias de centavos
                                //ValorCESC += ROUND(((ROUND((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1),0.01);
                                ValorCESC += ((TransSalesEntry."VAT Amount" * -1) - IVAtemp);
                            END;
                        UNTIL TransSalesEntry.NEXT = 0;
                    //CSMQ141016+
                    Total += (TransHeader."Gross Amount" * -1); //WVILLALTA 10.4.23-
                                                                //Total += TransHeader.Payment;               //WVILLALTA 10.4.23+
                                                                //Total += ValorExento + ValorGrabado;
                    TransPaymEntry.RESET;
                    TransPaymEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    IF TransPaymEntry.FIND('-') AND NOT TransSalesEntry.ISEMPTY THEN
                        REPEAT

                            //WVILLALTA 09.21-
                            IF (TransPaymEntry."Tender Type" = '21') AND TransHeader."Sale Is Return Sale" THEN BEGIN
                                TotalEfectivo += TransPaymEntry."Amount Tendered";
                                EfectivoDomicilioARecibir += TransPaymEntry."Amount Tendered";
                            END ELSE
                                //WVILLALTA 09.21-

                                //Contado
                                IF (TransPaymEntry."Tender Type" = '1') OR (TransPaymEntry."Tender Type" = '2') OR (TransPaymEntry."Tender Type" = '8') THEN     //ITFNPF10122016 Agregar Media de Pago Vale $15
                                    TotalEfectivo += TransPaymEntry."Amount Tendered"
                                //Credito
                                ELSE
                                    IF (TransPaymEntry."Tender Type" = '4') THEN
                                        TotalCredito += TransPaymEntry."Amount Tendered"
                                    ELSE
                                        IF (TransPaymEntry."Tender Type" = '25') THEN   //WVILLALTA 03.22-
                                            TotalGiftCard += TransPaymEntry."Amount Tendered"  //WVILLALTA 03.22+
                                                                                               //Puntos
                                        ELSE
                                            IF TransPaymEntry."Tender Type" = '11' THEN // ITPF111018
                                                TotalPuntos += TransPaymEntry."Amount Tendered" // Calculo de Total De Puntos Utilizados
                                            ELSE
                                                IF TransPaymEntry."Tender Type" = '17' THEN //FRODRIGUEZ07JUN21
                                                    TotalHugoPay += TransPaymEntry."Amount Tendered"
                                                ELSE
                                                    IF TransPaymEntry."Tender Type" = '16' THEN//FRODRIGUEZ07JUN21
                                                        TotalBTC += TransPaymEntry."Amount Tendered"

                                                    //Efectivo Domicilio
                                                    //ELSE IF TransPaymEntry."Tender Type" = '21' THEN              //CSMQ070316
                                                    //TotalEfectivoDomicilio += TransPaymEntry."Amount Tendered"  //Calculo Efectivo Domicilio
                                                    //Tarjetas de Credito
                                                    ELSE
                                                        IF (TransPaymEntry."Tender Type" = '20') OR (TransPaymEntry."Tender Type" = '5') THEN BEGIN  //Cambio para tarjetas de credito   //ITPF190917
                                                            gExtraData := '';
                                                            gInCardEntry := FALSE;
                                                            /* JH19072024Se han reportado demasiados campos clave, se cambia get por setrange
                                                            IF gPOSCardEntry.GET(TransPaymEntry."Store No.", TransPaymEntry."POS Terminal No.", TransPaymEntry."Receipt No.", TransPaymEntry."Line No.") THEN BEGIN
                                                                gInCardEntry := TRUE;
                                                                IF gPOSCardEntry."Extra Data" <> '' THEN
                                                                    gExtraData := gPOSCardEntry."Extra Data"
                                                                ELSE
                                                                    IF gBinBank.GET(gPOSCardEntry."FSN BIN No.") THEN
                                                                        IF gBinBank."Extra Data" <> '' THEN
                                                                            gExtraData := gBinBank."Extra Data";
                                                            END;
                                                            */

                                                            gPOSCardEntry.Reset();
                                                            gPOSCardEntry.SetRange("Store No.", TransPaymEntry."Store No.");
                                                            gPOSCardEntry.SetRange("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                            gPOSCardEntry.SetRange("Receipt No.", TransPaymEntry."Receipt No.");
                                                            gPOSCardEntry.SetRange("Line No.", TransPaymEntry."Line No.");
                                                            if gPOSCardEntry.FindFirst() then begin
                                                                repeat
                                                                    gInCardEntry := TRUE;
                                                                    IF gPOSCardEntry."Extra Data" <> '' THEN
                                                                        gExtraData := gPOSCardEntry."Extra Data"
                                                                    ELSE
                                                                        IF gBinBank.GET(gPOSCardEntry."FSN BIN No.") THEN
                                                                            IF gBinBank."Extra Data" <> '' THEN
                                                                                gExtraData := gBinBank."Extra Data";
                                                                until gPOSCardEntry.Next() = 0;
                                                            END;
                                                            IF gInCardEntry THEN
                                                                CASE gExtraData OF
                                                                    'ATH':
                                                                        BEGIN
                                                                            PITSSales.TARJETA1_ID := gExtraData;
                                                                            ATH += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CITI':
                                                                        BEGIN
                                                                            PITSSales.TARJETA2_ID := gExtraData;
                                                                            CITI += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CREDOMATIC':
                                                                        BEGIN
                                                                            PITSSales.TARJETA3_ID := gExtraData;
                                                                            Credomatic += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    ELSE BEGIN  //ITPF010817
                                                                        PITSSales.TARJETA1_ID := 'ATH';
                                                                        ATH += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                END;
                                                            IF NOT gInCardEntry THEN BEGIN
                                                                //TotalCredito += TransPaymEntry."Amount Tendered";
                                                                TransInfocodeEntry.RESET;
                                                                TransInfocodeEntry.SETRANGE("Store No.", TransPaymEntry."Store No.");
                                                                TransInfocodeEntry.SETRANGE("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                                TransInfocodeEntry.SETRANGE("Transaction No.", TransPaymEntry."Transaction No.");
                                                                TransInfocodeEntry.SETRANGE("Transaction Type", TransInfocodeEntry."Transaction Type"::"Payment Entry");
                                                                TransInfocodeEntry.SETRANGE("Line No.", TransPaymEntry."Line No.");
                                                                TransInfocodeEntry.SETRANGE(Infocode, 'TIPOTARJET');
                                                                IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                    //Orden de emisores: 1.ATH 2.CITI 3.CREDOMATIC
                                                                    CASE TransInfocodeEntry.Information OF
                                                                        'ATH':
                                                                            BEGIN
                                                                                PITSSales.TARJETA1_ID := TransInfocodeEntry.Information;
                                                                                ATH += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CITI':
                                                                            BEGIN
                                                                                PITSSales.TARJETA2_ID := TransInfocodeEntry.Information;
                                                                                CITI += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CREDOMATIC':
                                                                            BEGIN
                                                                                PITSSales.TARJETA3_ID := TransInfocodeEntry.Information;
                                                                                Credomatic += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        ELSE BEGIN  //ITPF010817
                                                                            PITSSales.TARJETA1_ID := 'ATH';
                                                                            ATH += TransPaymEntry."Amount Tendered";
                                                                            //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    END;
                                                                END
                                                                ELSE BEGIN
                                                                    TransInfocodeEntry.SETRANGE(Infocode, 'EMISORES');
                                                                    IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                        //Orden de emisores: 1.ATH 2.CITI 3.CREDOMATIC
                                                                        CASE TransInfocodeEntry.Information OF
                                                                            'ATH', 'AGRICOLA', 'SCOTIABANK':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA1_ID := 'ATH';
                                                                                    ATH += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            'CITI':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA2_ID := 'CITI';
                                                                                    CITI += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            'CREDOMATIC', 'BAC CREDOMATIC':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA3_ID := 'CREDOMATIC';
                                                                                    Credomatic += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            ELSE BEGIN  //ITPF010817
                                                                                PITSSales.TARJETA1_ID := 'ATH';
                                                                                ATH += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        END;
                                                                    END ELSE BEGIN
                                                                        PITSSales.TARJETA1_ID := 'ATH';
                                                                        ATH += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                END;
                                                            END;//WVILLALTA26JUL19+
                                                        END;
                            PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard
                        UNTIL TransPaymEntry.NEXT = 0;
                    //TransHeader.Registered := TRUE;//JH29052024 Se comenta debido a que se procesaran todos los registros
                    TransHeader.MODIFY;
                    //****************************************************************************
                    //Se terminan de insertar los valores
                    //  ***********************************Tipos de pago**************************//  //
                    //                                                                                //
                    //  MX (Mixto)                                                                    //
                    //  EF (Solo efectivo)                                                            //
                    //  CR (Solo credito)                                                             //
                    //  VD (Voided [Transacciones anulada])                                             //
                    //                                                                                //

                    IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito <> 0) THEN  //FRODRIGUEZ07SEP21
                        PITSSales.TIPO_PAGO := 'MX'
                    ELSE
                        IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito = 0) THEN //FRODRIGUEZ07SEP21
                            PITSSales.TIPO_PAGO := 'EF'
                        ELSE
                            IF (TotalEfectivo = 0) AND ((TotalCredito <> 0) OR (ATH <> 0) OR (CITI <> 0) OR (Credomatic <> 0) OR (Other <> 0) OR (Promerica <> 0)
                            OR (PITSSales.TARJETA1_VALOR <> 0) OR (PITSSales.TARJETA2_VALOR <> 0) OR (PITSSales.TARJETA3_VALOR <> 0) OR (PITSSales.TARJETA4_VALOR <> 0)
                            OR (PITSSales.TOTAL_CREDITO <> 0)
                            ) THEN     //ITPF010817
                                PITSSales.TIPO_PAGO := 'CR'
                            ELSE
                                PITSSales.TIPO_PAGO := 'VD';
                    //
                    //PITSSales.DOCUMENTO_FINAL := TransHeader.NCF;                   //   MAS
                    IF TransHeader."Sale Is Return Sale" THEN BEGIN                   //CSMQ230216
                        PITSSales.NUMERO_DOC_ANULADO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NFC Affected");
                        //Aqui van algunas cosas como la fecha
                        LocalTransHeader.RESET;
                        LocalTransHeader.SETRANGE("Receipt No.", TransHeader."Retrieved from Receipt No.");
                        LocalTransHeader.SETRANGE("FSN NCF", TransHeader."FSN NFC Affected");

                        IF LocalTransHeader.FINDFIRST THEN
                            PITSSales.FECHA_DOC_ANULADO := LocalTransHeader.Date;
                    END;

                    IF TransHeader."FSN NCF" <> '' THEN                                                                     //03.23-
                        PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");
                    IF PITSSales.DOCUMENTO_INICIAL = '' THEN
                        PITSSales.DOCUMENTO_INICIAL := PITSSales.DOCUMENTO_FINAL;                                       //03.23+

                    PITSSales.VALOR_VENTA_EXENTA := ValorExento;                     //
                    PITSSales.VALOR_VENTA_GRABADA := ValorGrabado;                   //  COSAS
                    PITSSales.VALOR_IVA := ValorIVA;                                 //
                    PITSSales.VALOR_CESC := ValorCESC;  //CSMQ141016
                                                        //CSMQ180216 Nuevas******************************
                    PITSSales.REB_DEV_VTA_EXENTA := ValorNetoDevEx;
                    PITSSales.REB_DEV_VTA_GRABADA := ValorNetoDevGr;
                    PITSSales.IVA_REB_DEV_VTA_GRABADA := ValorIVADev;
                    PITSSales.CESC_REB_DEV_VTA_GRABADA := ValorCESCDev; //CSMQ141016
                                                                        //***********************************************
                                                                        //CSMQ240216 Tarjetas de Credito*****************
                    PITSSales.TARJETA1_VALOR := ATH;
                    PITSSales.TARJETA2_VALOR := CITI;
                    PITSSales.TARJETA3_VALOR := Credomatic;
                    // PITSSales.TARJETA4_VALOR := Other;
                    PITSSales.TARJETA4_VALOR := Promerica; //ITPF0102017 Agrega nuevo emisor promerica
                                                           //***********************************************
                    PITSSales.TOTAL := Total;                                        //   EN
                    PITSSales.TOTAL_EFECTIVO := TotalEfectivo;                       //
                    PITSSales.TOTAL_CREDITO := TotalCredito;                         //  COMUN
                    PITSSales.EFECTIVO_DOMICILIO_A_RECIBIR := EfectivoDomicilioARecibir;  //CSMQ070316 Nuevas Variables
                    PITSSales.EFECTIVO_DOMICILIO_A_ENVIAR := EfectivoDomicilioAEnviar;
                    PITSSales.TOTAL_PUNTOS := TotalPuntos;  //ITPF11102018 Nuevo Campo para total de puntos
                    PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard
                    PITSSales.HUGO_PAY := TotalHugoPay; //FRODRIGUEZ07SEP21
                    PITSSales.BITCOIN := TotalBTC; //FRODRIGUEZ07SEP21

                    //WVILLATA INC. EXP.-
                    IF TransHeader."Income/Exp. Amount" <> 0 THEN BEGIN
                        TransIncomeExp_l.RESET;
                        TransIncomeExp_l.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");

                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Store No.", TransHeader."Store No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."POS Terminal No.", TransHeader."POS Terminal No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Transaction No.", TransHeader."Transaction No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."No.", '12');
                        TransIncomeExp_l.CALCSUMS(TransIncomeExp_l."Net Amount", TransIncomeExp_l."VAT Amount");

                        PITSSales.VALOR_VENTA_GRABADA -= (TransIncomeExp_l."Net Amount" + TransIncomeExp_l."VAT Amount");
                        PITSSales.VALOR_IVA -= TransIncomeExp_l."VAT Amount";
                        PITSSales.TOTAL -= (TransIncomeExp_l."Net Amount" + TransIncomeExp_l."VAT Amount");
                    END;
                    //WVILLATA INC. EXP.+

                    PITSSales.INSERT(TRUE);
                    RowsAffected += 1;                                               //

                    //*************************Se genera una nueva linea y se limpian variables
                    InsertNew := TRUE;
                    ClearVariables;
                END
                //*****************************************************************************************
                ELSE BEGIN  //Si la transaccion es una venta normal
                    IF InsertNew THEN BEGIN //Se inicializa una nueva linea porque la anterior no existe o fue una devolucion
                                            //Inicializar nueva linea
                        CLEAR(PITSSales);
                        PITSSales.INIT;                                                  //  COSAS
                        PITSSales.FECHA_DOCUMENTO := TransHeader.Date;                   //
                        PITSSales.SUCURSAL := Store."No.";                               //   EN
                        PITSSales.TIPO_TRANSACCION := DocumentTypeLocal;                 //
                        PITSSales.NCF := TransHeader."FSN NCF"; //CSMQ070316 Nueva columna para NCF
                        PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");        //  COMUN
                        PITSSales.DOCUMENTO_INICIAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");
                        //
                        //PITSSales.CODIGO_CLIENTE := '-';                                 //    DE
                        PITSSales.NOMBRE_CLIENTE := 'CLIENTES VARIOS';                   //
                                                                                         //PITSSales.REGISTRO_CLIENTE := 'NO APLICA';                       // TICKETS
                        PITSSales.CAJA := TransHeader."POS Terminal No.";                //
                                                                                         //PITSSales.TIPO_PAGO := 'YV';   //Revisar                         //
                        InsertNew := FALSE;
                    END;

                    IF STRLEN(PITSSales.NCF) < 4 THEN BEGIN                                                                  //WVILLALTA 03.23-
                        PITSSales.NCF := TransHeader."FSN NCF";
                        PITSSales.SERIE_DOCUMENTO := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");
                        PITSSales.DOCUMENTO_INICIAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");     //WVILLALTA 03.23+
                    END;
                    IF TransHeader."FSN NCF" <> '' THEN                                                                     //03.23-
                        PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");//03.23+


                    //Quizas deberia ser aqui
                    //CSMQ070316 Probemos*******************************************************************
                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                    IF NOT TransSalesEntry.FIND THEN BEGIN
                        TransInfocodeEntry.RESET;
                        TransInfocodeEntry.SETRANGE("Store No.", TransHeader."Store No.");
                        TransInfocodeEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");
                        TransInfocodeEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                        TransInfocodeEntry.SETRANGE("Transaction Type", TransInfocodeEntry."Transaction Type"::"Income/Expense Entry");
                        TransInfocodeEntry.SETRANGE(Infocode, 'SUCDESTINO');
                        IF TransInfocodeEntry.FIND('-') THEN
                            REPEAT
                                EfectivoDomicilioAEnviar += (TransInfocodeEntry.Amount * -1);
                            UNTIL TransInfocodeEntry.NEXT = 0;
                    END;
                    //**************************************************************************************
                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");
                    //Exento
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 0');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            ValorExento += (TransSalesEntry."Total Rounded Amt." * -1);
                        UNTIL TransSalesEntry.NEXT = 0;
                    //Grabado
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 13');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1); // CSALX20161221
                                                                                         //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                            ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                        UNTIL TransSalesEntry.NEXT = 0;
                    //Con CESC
                    TransSalesEntry.SETRANGE("VAT Code");
                    TransSalesEntry.SETRANGE("VAT Code", 'IVA 18');
                    IF TransSalesEntry.FIND('-') THEN
                        REPEAT
                            ValorGrabado += (TransSalesEntry."Total Rounded Amt." * -1); // CSALX20161221
                                                                                         //ValorGrabado += (TransSalesEntry."Net Amount" * -1);
                            ValorIVA += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                            IVAtemp := (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * (POSVATCode."VAT %" / 100)) * -1);
                            //CSPNT141016ValorCESC += (((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1);
                            //ROUND(ROUND(vMontoAcreditado/1.18,0.01) * 0.05,0.01)
                            //ValorCESC += ROUND(((ROUND((TransSalesEntry."Total Rounded Amt." / (1 + (POSVATCode18."VAT %" / 100))),0.01) * ((POSVATCode18."VAT %" - POSVATCode."VAT %") / 100)) * -1),0.01);
                            ValorCESC += ((TransSalesEntry."VAT Amount" * -1) - IVAtemp);
                        UNTIL TransSalesEntry.NEXT = 0;
                    Total += (TransHeader."Gross Amount" * -1);
                    //Total += ValorExento + ValorGrabado;
                    TransPaymEntry.RESET;
                    TransPaymEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransPaymEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    TransSalesEntry.RESET;
                    TransSalesEntry.SETRANGE("Store No.", TransHeader."Store No."); //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("POS Terminal No.", TransHeader."POS Terminal No.");  //CSMQ190416 Filtrado mas granular
                    TransSalesEntry.SETRANGE("Transaction No.", TransHeader."Transaction No.");

                    IF TransPaymEntry.FIND('-') AND NOT TransSalesEntry.ISEMPTY THEN
                        REPEAT
                            //Contado
                            IF ((TransPaymEntry."Tender Type" = '1') OR (TransPaymEntry."Tender Type" = '2') OR (TransPaymEntry."Tender Type" = '8')) THEN //ITFNPF10122016
                                TotalEfectivo += TransPaymEntry."Amount Tendered"
                            //Credito
                            ELSE
                                IF (TransPaymEntry."Tender Type" = '4') THEN
                                    TotalCredito += TransPaymEntry."Amount Tendered"
                                //Efectivo Domicilio
                                ELSE
                                    IF TransPaymEntry."Tender Type" = '21' THEN              //CSMQ070316
                                        EfectivoDomicilioARecibir += TransPaymEntry."Amount Tendered"  //Calculo Efectivo Domicilio
                                    ELSE
                                        IF TransPaymEntry."Tender Type" = '11' THEN // ITPF111018
                                            TotalPuntos += TransPaymEntry."Amount Tendered" // Calculo de Total De Puntos Utilizados

                                        ELSE
                                            IF TransPaymEntry."Tender Type" = '25' THEN //ITPF26032021
                                                TotalGiftCard += TransPaymEntry."Amount Tendered"
                                            ELSE
                                                IF TransPaymEntry."Tender Type" = '17' THEN //FRODRIGUEZ07JUN21
                                                    TotalHugoPay += TransPaymEntry."Amount Tendered"
                                                ELSE
                                                    IF TransPaymEntry."Tender Type" = '16' THEN//FRODRIGUEZ07JUN21
                                                        TotalBTC += TransPaymEntry."Amount Tendered"



                                                    //Tarjetas de Credito
                                                    ELSE
                                                        IF (TransPaymEntry."Tender Type" = '20') OR (TransPaymEntry."Tender Type" = '5') THEN BEGIN  //Cambio para tarjetas de credito   //ITPF190917
                                                            gExtraData := '';
                                                            gInCardEntry := FALSE;

                                                            /* JH19072024 Se han reportado demasiados campos clave, se cambia get por setrange
                                                            IF gPOSCardEntry.GET(TransPaymEntry."Store No.", TransPaymEntry."POS Terminal No.", TransPaymEntry."Receipt No.", TransPaymEntry."Line No.") THEN BEGIN
                                                                gInCardEntry := TRUE;
                                                                IF gPOSCardEntry."Extra Data" <> '' THEN
                                                                    gExtraData := gPOSCardEntry."Extra Data"
                                                                ELSE
                                                                    IF gBinBank.GET(gPOSCardEntry."FSN BIN No.") THEN
                                                                        IF gBinBank."Extra Data" <> '' THEN
                                                                            gExtraData := gBinBank."Extra Data";
                                                            END;
                                                            */
                                                            gPOSCardEntry.Reset();
                                                            gPOSCardEntry.SetRange("Store No.", TransPaymEntry."Store No.");
                                                            gPOSCardEntry.SetRange("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                            gPOSCardEntry.SetRange("Receipt No.", TransPaymEntry."Receipt No.");
                                                            gPOSCardEntry.SetRange("Line No.", TransPaymEntry."Line No.");
                                                            if gPOSCardEntry.FindFirst() then begin
                                                                repeat
                                                                    gInCardEntry := TRUE;
                                                                    IF gPOSCardEntry."Extra Data" <> '' THEN
                                                                        gExtraData := gPOSCardEntry."Extra Data"
                                                                    ELSE
                                                                        IF gBinBank.GET(gPOSCardEntry."FSN BIN No.") THEN
                                                                            IF gBinBank."Extra Data" <> '' THEN
                                                                                gExtraData := gBinBank."Extra Data";
                                                                until gPOSCardEntry.Next() = 0;
                                                            END;
                                                            IF gInCardEntry THEN
                                                                CASE gExtraData OF
                                                                    'ATH':
                                                                        BEGIN
                                                                            PITSSales.TARJETA1_ID := gExtraData;
                                                                            ATH += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CITI':
                                                                        BEGIN
                                                                            PITSSales.TARJETA2_ID := gExtraData;
                                                                            CITI += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    'CREDOMATIC':
                                                                        BEGIN
                                                                            PITSSales.TARJETA3_ID := gExtraData;
                                                                            Credomatic += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    ELSE BEGIN
                                                                        PITSSales.TARJETA1_ID := 'ATH';
                                                                        ATH += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                END;
                                                            IF NOT gInCardEntry THEN BEGIN
                                                                //TotalCredito += TransPaymEntry."Amount Tendered";
                                                                TransInfocodeEntry.RESET;
                                                                TransInfocodeEntry.SETRANGE("Store No.", TransPaymEntry."Store No.");
                                                                TransInfocodeEntry.SETRANGE("POS Terminal No.", TransPaymEntry."POS Terminal No.");
                                                                TransInfocodeEntry.SETRANGE("Transaction No.", TransPaymEntry."Transaction No.");
                                                                TransInfocodeEntry.SETRANGE("Transaction Type", TransInfocodeEntry."Transaction Type"::"Payment Entry");
                                                                TransInfocodeEntry.SETRANGE("Line No.", TransPaymEntry."Line No.");
                                                                TransInfocodeEntry.SETRANGE(Infocode, 'TIPOTARJET');
                                                                IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                    //Orden de emisores: 1.ATH 2.CITI 3.CREDOMATIC
                                                                    CASE TransInfocodeEntry.Information OF
                                                                        'ATH':
                                                                            BEGIN
                                                                                PITSSales.TARJETA1_ID := TransInfocodeEntry.Information;
                                                                                ATH += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CITI':
                                                                            BEGIN
                                                                                PITSSales.TARJETA2_ID := TransInfocodeEntry.Information;
                                                                                CITI += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        'CREDOMATIC':
                                                                            BEGIN
                                                                                PITSSales.TARJETA3_ID := TransInfocodeEntry.Information;
                                                                                Credomatic += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        ELSE BEGIN
                                                                            PITSSales.TARJETA1_ID := 'ATH';
                                                                            ATH += TransPaymEntry."Amount Tendered";
                                                                            //PITSSales.TARJETA4_VALOR += TransPaymEntry."Amount Tendered";
                                                                        END;
                                                                    END;
                                                                END
                                                                ELSE BEGIN
                                                                    TransInfocodeEntry.SETRANGE(Infocode, 'EMISORES');
                                                                    IF TransInfocodeEntry.FINDFIRST THEN BEGIN
                                                                        //Orden de emisores: 1.ATH 2.CITI 3.CREDOMATIC
                                                                        CASE TransInfocodeEntry.Information OF
                                                                            'ATH', 'AGRICOLA', 'SCOTIABANK':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA1_ID := 'ATH';
                                                                                    ATH += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA1_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            'CITI':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA2_ID := 'CITI';
                                                                                    CITI += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA2_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            'CREDOMATIC', 'BAC CREDOMATIC':
                                                                                BEGIN
                                                                                    PITSSales.TARJETA3_ID := 'CREDOMATIC';
                                                                                    Credomatic += TransPaymEntry."Amount Tendered";
                                                                                    //PITSSales.TARJETA3_VALOR += TransPaymEntry."Amount Tendered";
                                                                                END;
                                                                            ELSE BEGIN
                                                                                PITSSales.TARJETA1_ID := 'ATH';
                                                                                ATH += TransPaymEntry."Amount Tendered";
                                                                                //PITSSales.TARJETA4_VALOR += TransPaymEntry."Amount Tendered";
                                                                            END;
                                                                        END;
                                                                    END ELSE BEGIN
                                                                        PITSSales.TARJETA1_ID := 'ATH';
                                                                        ATH += TransPaymEntry."Amount Tendered";
                                                                    END;
                                                                END;//WVILLALTA27JUN19-+
                                                            END;//WVILLALTA26JUL19+
                                                        END;

                        UNTIL TransPaymEntry.NEXT = 0;

                    ValorRetencion += TransHeader."FSN Retention Amount";
                    ValorPercepcion += TransHeader."FSN Perception Amount";
                    //TransHeader.Registered := TRUE; //JH29052024 Se comenta ya que se procesaran todos los registros
                    TransHeader.MODIFY;

                    //WVILLATA INC. EXP.-
                    IF TransHeader."Income/Exp. Amount" <> 0 THEN BEGIN
                        TransIncomeExp_l.RESET;
                        TransIncomeExp_l.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");

                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Store No.", TransHeader."Store No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."POS Terminal No.", TransHeader."POS Terminal No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Transaction No.", TransHeader."Transaction No.");
                        TransIncomeExp_l.SETRANGE(TransIncomeExp_l."No.", '12');
                        TransIncomeExp_l.CALCSUMS(TransIncomeExp_l."Net Amount", TransIncomeExp_l."VAT Amount");

                        TransIncExpTmp.Amount += TransIncomeExp_l.Amount;
                        TransIncExpTmp."Net Amount" += TransIncomeExp_l."Net Amount";
                        TransIncExpTmp."VAT Amount" += TransIncomeExp_l."VAT Amount";
                    END;
                    //WVILLATA INC. EXP.+

                END;
            //END; Se comenta por que se procesaran todos los registros
            UNTIL TransHeader.NEXT = 0;
            IF InsertNew THEN //CSMQ020316 Si una nueva linea esta lista para insertarse pero ya no hay nada que insertar, termina la ejecucion
                EXIT;
            //  ***********************************Tipos de pago**************************//  //
            //                                                                                //
            //  MX (Mixto)                                                                    //
            //  EF (Solo efectivo)                                                            //
            //  CR (Solo credito)                                                             //
            //  VD (Voided [Transacciones anulada])                                             //
            //                                                                                //
            IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito <> 0) THEN  //FRODRIGUEZ07SEP21
                PITSSales.TIPO_PAGO := 'MX'
            ELSE
                IF ((TotalEfectivo <> 0) OR (TotalHugoPay <> 0) OR (TotalBTC <> 0)) AND (TotalCredito = 0) THEN //FRODRIGUEZ07SEP21
                    PITSSales.TIPO_PAGO := 'EF'
                ELSE
                    IF (TotalEfectivo = 0) AND ((TotalCredito <> 0) OR (ATH <> 0) OR (CITI <> 0) OR (Credomatic <> 0) OR (Other <> 0) OR (Promerica <> 0)
                    OR (PITSSales.TARJETA1_VALOR <> 0) OR (PITSSales.TARJETA2_VALOR <> 0) OR (PITSSales.TARJETA3_VALOR <> 0) OR (PITSSales.TARJETA4_VALOR <> 0)
                    OR (PITSSales.TOTAL_CREDITO <> 0)
                    ) THEN   //ITPF010817
                        PITSSales.TIPO_PAGO := 'CR'
                    ELSE
                        PITSSales.TIPO_PAGO := 'VD';
            //
            IF TransHeader."FSN NCF" <> '' THEN                                                                     //03.23-
                PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader."FSN NCF");//03.23+
                                                                                                                         //PITSSales.DOCUMENTO_FINAL := STRSUBSTNO('%1-%2', TransHeader."FSN No. Serie NCF", TransHeader.NCF);  //   MAS
            PITSSales.VALOR_VENTA_EXENTA := ValorExento;                     //
            PITSSales.VALOR_VENTA_GRABADA := ValorGrabado;                   //  COSAS
            PITSSales.VALOR_IVA := ValorIVA;                                 //
            PITSSales.VALOR_CESC := ValorCESC; //CSMQ141016
                                               //CSMQ180216 Nuevas******************************
            PITSSales.REB_DEV_VTA_EXENTA := ValorNetoDevEx;
            PITSSales.REB_DEV_VTA_GRABADA := ValorNetoDevGr;
            PITSSales.IVA_REB_DEV_VTA_GRABADA := ValorIVADev;
            PITSSales.CESC_REB_DEV_VTA_GRABADA := ValorCESCDev;  //CSMQ141016
                                                                 //***********************************************
                                                                 //CSMQ240216 Tarjetas de Credito*****************
            PITSSales.TARJETA1_VALOR := ATH;
            PITSSales.TARJETA2_VALOR := CITI;
            PITSSales.TARJETA3_VALOR := Credomatic;
            //PITSSales.TARJETA4_VALOR := Other;
            PITSSales.TARJETA4_VALOR := Promerica;    //ITPF010817
                                                      //***********************************************
            PITSSales.TOTAL := Total;                                        //   EN
            PITSSales.TOTAL_EFECTIVO := TotalEfectivo + EfectivoDomicilioARecibir;                       //
            PITSSales.TOTAL_CREDITO := TotalCredito;                         //  COMUN
            PITSSales.EFECTIVO_DOMICILIO_A_RECIBIR := EfectivoDomicilioARecibir;  //CSMQ070316 Nuevas Variables
            PITSSales.EFECTIVO_DOMICILIO_A_ENVIAR := EfectivoDomicilioAEnviar;
            PITSSales.TOTAL_PUNTOS := TotalPuntos;  //ITPF11102018 Nuevo Campo para total de puntos
            PITSSales.GIFTCARD := TotalGiftCard; //ITPF05042021 Nuevo Campo para total GiftCard
                                                 //***********************************************
            PITSSales.MONTO_RETENCION := ValorRetencion;
            PITSSales.MONTO_PERCEPCION := ValorPercepcion;
            PITSSales.HUGO_PAY := TotalHugoPay; //FRODRIGUEZ07SEP21
            PITSSales.BITCOIN := TotalBTC; //FRODRIGUEZ07SEP21

            //WVILLATA INC. EXP.-
            IF TransIncExpTmp."Net Amount" <> 0 THEN BEGIN
                /*TransIncomeExp_l.RESET;
                TransIncomeExp_l.SETCURRENTKEY("Store No.","POS Terminal No.","Transaction No.","Line No.");

                TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Store No.",TransHeader."Store No.");
                TransIncomeExp_l.SETRANGE(TransIncomeExp_l."POS Terminal No.",TransHeader."POS Terminal No.");
                TransIncomeExp_l.SETRANGE(TransIncomeExp_l."Transaction No.",TransHeader."Transaction No.");
                TransIncomeExp_l.SETRANGE(TransIncomeExp_l."No.",'12');
                TransIncomeExp_l.CALCSUMS(TransIncomeExp_l."Net Amount",TransIncomeExp_l."VAT Amount");
                 */
                PITSSales.VALOR_VENTA_GRABADA -= (TransIncExpTmp."Net Amount" + TransIncExpTmp."VAT Amount");
                PITSSales.VALOR_IVA -= TransIncExpTmp."VAT Amount";
                PITSSales.TOTAL -= (TransIncExpTmp."Net Amount" + TransIncExpTmp."VAT Amount");
            END;
            //WVILLATA INC. EXP.+

            PITSSales.INSERT(TRUE);
            RowsAffected += 1;                                               //
        END;

    end;

    procedure ValidateBC()
    var
        TransHeader: Record "LSC Transaction Header";
        ReplicationVerify: Record "FSN Replication Verify";
        i: Integer;
        TERM: Record "LSC POS Terminal";
        done: Boolean;
        TransIncomEx_l: Record "LSC Trans. Inc./Exp. Entry";
    begin
        ReplicationVerify.RESET;
        ReplicationVerify.SETRANGE(ReplicationVerify.DB_Name, 'DBTIENDA');
        //ReplicationVerify.SETRANGE(ReplicationVerify.StoreNo,'F56'); //
        IF ReplicationVerify.FIND('-') THEN
            REPEAT
                //IF ReplicationVerify.StoreNo = ReplicationVerify.Terminal THEN BEGIN

                TERM.RESET;
                TERM.SETRANGE(TERM."Store No.", ReplicationVerify.StoreNo);
                //TERM.SETFILTER(TERM."No.",'>%1','PV#280');
                IF TERM.FIND('-') THEN
                    REPEAT

                        TransHeader.RESET;
                        TransHeader.SETCURRENTKEY("POS Terminal No.", "Transaction Type", Date, "Entry Status");
                        TransHeader.SETRANGE(TransHeader."POS Terminal No.", TERM."No.");
                        TransHeader.SETRANGE(TransHeader."Transaction Type", TransHeader."Transaction Type"::Sales);
                        TransHeader.SETFILTER(TransHeader.Date, '>=%1&<=%2', TODAY - 17, TODAY - 1);
                        //TransHeader.SETRANGE(TransHeader.Date,DMY2DATE(24,12,2023));
                        TransHeader.SETRANGE(TransHeader."Entry Status", 0);
                        //MESSAGE(FORMAT(TransHeader.COUNT));
                        //EXIT;
                        IF TransHeader.FIND('-') THEN
                            REPEAT
                                IF TransHeader."Store No." = 'F63' THEN
                                    TransHeader."Store No." := 'F63';

                                done := FALSE;
                                IF TransHeader."FSN Correlative" <> TransHeader."FSN NCF" THEN BEGIN
                                    TransHeader."FSN Correlative" := TransHeader."FSN NCF";
                                    done := TRUE;
                                END;
                                IF NOT (TransHeader."FSN Document Type"::Ticket = TransHeader."FSN Document Type") AND
                                  NOT (TransHeader."FSN Document Type"::Factura = TransHeader."FSN Document Type") AND
                                  NOT (TransHeader."FSN Document Type"::"Credito Fiscal" = TransHeader."FSN Document Type") AND
                                  NOT (TransHeader."FSN Document Type"::"Nota Credito" = TransHeader."FSN Document Type") AND
                                  NOT (TransHeader."FSN Document Type"::"Devolucion Factura" = TransHeader."FSN Document Type") THEN BEGIN
                                    done := TRUE;
                                    CASE TRUE OF
                                        (TransHeader."FSN No. Serie NCF" = 'MANUAL'):
                                            BEGIN
                                                IF COPYSTR(TransHeader."FSN Fiscal Serie Affected", 8, 1) = 'C' THEN
                                                    TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::"Credito Fiscal"
                                                ELSE
                                                    IF ((COPYSTR(TransHeader."FSN Fiscal Serie Affected", 8, 1) = 'F') OR (COPYSTR(TransHeader."FSN Fiscal Serie Affected", 9, 1) = 'F')) THEN
                                                        TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::Factura
                                                    ELSE
                                                        IF COPYSTR(TransHeader."FSN Fiscal Serie Affected", 8, 1) = 'T' THEN
                                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::"Nota Credito";
                                            END;

                                        STRPOS(TransHeader."FSN No. Serie NCF", 'TICKET') > 0:
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::Ticket;
                                        STRPOS(TransHeader."FSN No. Serie NCF", 'FAC') > 0:
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::Factura;
                                        STRPOS(TransHeader."FSN No. Serie NCF", 'CREF') > 0:
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::"Credito Fiscal";
                                        STRPOS(TransHeader."FSN No. Serie NCF", 'DEV') > 0:
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::"Devolucion Factura";
                                        STRPOS(TransHeader."FSN No. Serie NCF", 'NOC') > 0:
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::"Nota Credito";
                                        ELSE
                                            TransHeader."FSN Document Type" := TransHeader."FSN Document Type"::Ticket;
                                            ;
                                    END;
                                END;
                                IF done THEN
                                    TransHeader.MODIFY;
                            UNTIL TransHeader.NEXT = 0;


                        COMMIT;
                    UNTIL TERM.NEXT = 0;
            //END;
            UNTIL ReplicationVerify.NEXT = 0;

        TransIncomEx_l.RESET;
        TransIncomEx_l.SETRANGE(TransIncomEx_l.Date, TODAY - 17, TODAY - 1);
        TransIncomEx_l.SETRANGE(TransIncomEx_l."No.", '12');
        IF TransIncomEx_l.FIND('-') THEN
            REPEAT
                IF TransHeader.GET(TransIncomEx_l."Store No.", TransIncomEx_l."POS Terminal No.", TransIncomEx_l."Transaction No.") THEN
                    IF TransHeader."Income/Exp. Amount" = 0 THEN BEGIN
                        TransHeader."Income/Exp. Amount" := TransIncomEx_l.Amount;
                        TransHeader.MODIFY;
                    END;
            UNTIL TransIncomEx_l.NEXT = 0;
    end;

    procedure CompressInvoice(var pTempTable: Record "FSN PITS_ventas"; var pInsertTable: Record "FSN PITS_ventas"): Boolean
    begin
        IF (LASTTempPITSSales.SUCURSAL <> LASTInsertPITSSales.SUCURSAL) OR
          (LASTTempPITSSales.CAJA <> LASTInsertPITSSales.CAJA) OR
          (LASTTempPITSSales.FECHA_DOCUMENTO <> LASTInsertPITSSales.FECHA_DOCUMENTO) OR
          (NOT LASTTempPITSSales.DTE) THEN
            EXIT(FALSE);

        IF (LASTInsertPITSSales.DTE) AND (LASTInsertPITSSales.DTE_CODIGO_CONTROL = '') THEN
            EXIT(FALSE);


        IF (LASTTempPITSSales.FECHA_DOC_ANULADO <> 0D) OR
          (LASTTempPITSSales.NUMERO_DOC_ANULADO <> '') THEN
            EXIT(FALSE);

        LASTInsertPITSSales.DOCUMENTO_FINAL := LASTTempPITSSales.DOCUMENTO_INICIAL;
        LASTInsertPITSSales.CODIGO_CLIENTE := '';
        LASTInsertPITSSales.NOMBRE_CLIENTE := 'CLIENTES VARIOS';
        LASTInsertPITSSales.REFERENCIA_CLIENTE_EBS := '';
        LASTInsertPITSSales.TIPO_PAGO := 'EF';
        LASTInsertPITSSales.VALOR_VENTA_EXENTA += LASTTempPITSSales.VALOR_VENTA_EXENTA;
        LASTInsertPITSSales.REB_DEV_VTA_EXENTA += LASTTempPITSSales.REB_DEV_VTA_EXENTA;
        LASTInsertPITSSales.VALOR_VENTA_GRABADA += LASTTempPITSSales.VALOR_VENTA_GRABADA;
        LASTInsertPITSSales.REB_DEV_VTA_GRABADA += LASTTempPITSSales.REB_DEV_VTA_GRABADA;
        LASTInsertPITSSales.EFECTIVO_DOMICILIO_A_RECIBIR += LASTTempPITSSales.EFECTIVO_DOMICILIO_A_RECIBIR;
        LASTInsertPITSSales.EFECTIVO_DOMICILIO_A_ENVIAR += LASTTempPITSSales.EFECTIVO_DOMICILIO_A_ENVIAR;
        LASTInsertPITSSales.VALOR_IVA += LASTTempPITSSales.VALOR_IVA;
        LASTInsertPITSSales.IVA_REB_DEV_VTA_GRABADA += LASTTempPITSSales.IVA_REB_DEV_VTA_GRABADA;
        LASTInsertPITSSales.VALOR_CESC += LASTTempPITSSales.VALOR_CESC;
        LASTInsertPITSSales.CESC_REB_DEV_VTA_GRABADA += LASTTempPITSSales.CESC_REB_DEV_VTA_GRABADA;
        LASTInsertPITSSales.TOTAL += LASTTempPITSSales.TOTAL;
        LASTInsertPITSSales.TOTAL_EFECTIVO += LASTTempPITSSales.TOTAL_EFECTIVO;
        LASTInsertPITSSales.TOTAL_CREDITO += LASTTempPITSSales.TOTAL_CREDITO;
        LASTInsertPITSSales.TARJETA1_VALOR += LASTTempPITSSales.TARJETA1_VALOR;
        IF LASTTempPITSSales.TARJETA1_VALOR <> 0 THEN
            LASTInsertPITSSales.TARJETA1_ID := LASTTempPITSSales.TARJETA1_ID;
        LASTInsertPITSSales.TARJETA2_VALOR += LASTTempPITSSales.TARJETA2_VALOR;

        IF LASTTempPITSSales.TARJETA2_VALOR <> 0 THEN
            LASTInsertPITSSales.TARJETA2_ID := LASTTempPITSSales.TARJETA2_ID;

        LASTInsertPITSSales.TARJETA3_VALOR += LASTTempPITSSales.TARJETA3_VALOR;
        IF LASTTempPITSSales.TARJETA3_VALOR <> 0 THEN
            LASTInsertPITSSales.TARJETA3_ID := LASTTempPITSSales.TARJETA3_ID;

        LASTInsertPITSSales.TARJETA4_VALOR += LASTTempPITSSales.TARJETA4_VALOR;
        IF LASTTempPITSSales.TARJETA4_VALOR <> 0 THEN
            LASTInsertPITSSales.TARJETA4_ID := LASTTempPITSSales.TARJETA4_ID;

        LASTInsertPITSSales.MONTO_RETENCION += LASTTempPITSSales.MONTO_RETENCION;
        LASTInsertPITSSales.MONTO_PERCEPCION += LASTTempPITSSales.MONTO_PERCEPCION;
        LASTInsertPITSSales.TARJETA5_VALOR += LASTTempPITSSales.TARJETA5_VALOR;
        LASTInsertPITSSales.TOTAL_PUNTOS += LASTTempPITSSales.TOTAL_PUNTOS;
        LASTInsertPITSSales.GIFTCARD += LASTTempPITSSales.GIFTCARD;
        LASTInsertPITSSales.HUGO_PAY += LASTTempPITSSales.HUGO_PAY;
        LASTInsertPITSSales.BITCOIN += LASTTempPITSSales.BITCOIN;
        LASTInsertPITSSales.DTE_CODIGO_GENERACION_FINAL := LASTTempPITSSales.DTE_CODIGO_GENERACION_INICIO;

        IF LASTInsertPITSSales.DOCUMENTO_INICIAL = '' THEN
            LASTInsertPITSSales.DOCUMENTO_INICIAL := LASTInsertPITSSales.DTE_CODIGO_CONTROL;
        LASTInsertPITSSales.DOCUMENTO_FINAL := LASTTempPITSSales.DTE_CODIGO_CONTROL;

        LASTInsertPITSSales.MODIFY;
        EXIT(TRUE);
    end;


}
