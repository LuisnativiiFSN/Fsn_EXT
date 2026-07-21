codeunit 50063 "FSN POS Process Robot"
{
    TableNo = "LSC Scheduler Job Header";

    trigger OnRun()
    begin
        IF Rec.Code = 'RUNFV' THEN
            ProcessFacSales(Rec.integer);

        IF Rec.Code = 'PROCESSJNL' THEN
            ProcessJnl();

        IF Rec.Code = 'TEST' THEN
            TEST(Rec.Text, FORMAT(Rec.DateFormula), Rec.Integer, Rec.Decimal, 30000, 'FRASCOX1');

        IF Rec.Code = 'POS' THEN begin
            FSNwsProcRobotJrn.PosAdjTUseItemJrnTemplate(LeerArchivoTXT(), MssageError);
            message(MssageError);
        end;

        IF Rec.Code = 'NEG' THEN begin
            FSNwsProcRobotJrn.ValNegAdjTItemJrnTemplate(LeerArchivoTXT(), MssageError);
            message(MssageError);
        end;
    end;

    var
        POSSESSION: Codeunit "LSC POS Session";
        FSNUtility: Codeunit "FSN Utility";
        FSNParameter: Record "FSN Parameter";
        PrintUtil: Codeunit "LSC POS Print Utility";
        FSNwsProcRobotJrn: Codeunit "FSN WS Process Robot Jrn";
        MssageError: Text;
        SalesInvoice: Page "Sales Invoice";

    //Aplica ajuste mediante un areglo en un archivo externo tipo txt
    procedure LeerArchivoTXT(): Text
    var
        FileName: Text;
        InStr: InStream;
        StringText: Text;
        Linea: Text;
    begin
        if UploadIntoStream('Seleccione TXT', '', 'Text files (*.txt)|*.txt', FileName, InStr) then begin

            InStr.Read(StringText);
            exit(StringText);
        end;
    end;


    procedure TEST(receiptNo: Code[20]; Item: Code[20]; QuantityInv: Decimal; Quantity: Decimal; LineNo: Integer; UnitOfm: Code[10])
    var
        FSNwsProcRobotJrn: Codeunit "FSN WS Process Robot Jrn";
    begin
        FSNwsProcRobotJrn.InvetAlertRobot(receiptNo, Item, QuantityInv, Quantity, LineNo, UnitOfm);
    end;

    //Aplica journal line de inventario
    procedure ProcessJnl()
    var
        myInt: Integer;
        ItemJrnLine: Record "Item Journal Line";
        ErrorTextAplyJnl: Text;
        FSNWSProcRobotJrn: Codeunit "FSN WS Process Robot Jrn";
    begin
        ItemJrnLine.Reset();
        ItemJrnLine.SetRange("Journal Template Name", 'ROBOT');
        if ItemJrnLine.FindFirst() then
            if not FSNWSProcRobotJrn.ProcessJnlPost(ItemJrnLine, ErrorTextAplyJnl) then
                Message(ErrorTextAplyJnl);
    end;

    procedure ValidateUsePOS(OrderNo: Code[20]; var TerminalUsePos: Code[10]): Boolean;
    var
        "LSCTransInUseonPOS": Record "LSC Transaction in Use on POS";
    begin
        if LSCTransInUseonPOS.Get(OrderNo) then
            if LSCTransInUseonPOS."In Use on POS Terminal" <> POSSESSION.TerminalNo() then begin
                TerminalUsePos := LSCTransInUseonPOS."In Use on POS Terminal";
                exit(true);
            end else
                exit(false);
        exit(false);
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
(
var POSMenuLine: Record "LSC POS Menu Line";
var handled: Boolean
)
    var
        PosTrans: Record "LSC POS Transaction";
        POSCtrl: Codeunit "LSC POS Control Interface";
        OrderNo: Code[20];
        POSTransC: Codeunit "LSC POS Transaction";
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        ErrorMessage: Label 'Pedido ya Fue asignado al %1';
        LSMenu: Text[100];
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        jObject: JsonObject;
        TEXT000: Label 'Pedido %1 debe de Procesarce antes de Facturar';
        TEXT001: Label 'Pedido ya fue enviado al robot desde prefactura con GUID: %1';
        TEXT002: Label 'No se ha asignado Terminal del box desde DAF %1';
        TEXT003: Label 'El N° pedido %1 esta siendo facturado en el N° %2';
        FSNWSProcRobotJrn: Codeunit "FSN WS Process Robot Jrn";
        POSLine: Record "LSC POS Trans. Line";
        ErrorTextTest: Text;
        ItemJrnTemplete: Record "Item Journal Template";
        ItemJrnBatch: Record "Item Journal Batch";
        ItemJrnLine: Record "Item Journal Line";
        UnitOfm: Code[10];
        PosMenuLineTemp_: Record "LSC POS Menu Line" temporary;
        DelOrder: Record "LSC Delivery Order";
        CodeResult: Integer;
        Terminal: Code[10];
        RemissionNo: Code[20];
        AProcessed: Boolean;
        G: Codeunit "LSC Gift Receipt POS Commands";
        RecordIDStringArray: JsonArray;
        RecID: RecordID;
        Recref: RecordRef;
        RecIDToken: JsonToken;
        TXT_MARKED: Label 'Marked for Gift Receipt';
        POSTransInfocodeEntry: Record "LSC Pos Trans. infocode Entry";
        InUseOnPos: code[10];
        ParameterC: Record "FSN Parameter";
        FSNParameterRT: Record "FSN Parameter";
        DOrder: Record "LSC Delivery Order";
        prv: Record "FSN Parameter";
    begin

        //Comando interno para procesar el pedido
        if POSMenuLine.Command = 'HOSP-ORDEREDIT' then begin
            OrderNo := POSCtrl.GetDataGridKeyValue(POSCtrl.ActiveDataGrid);
            if FSNParameter.Get('ROBOT', 'PROCESSCALL') AND FSNParameter.Activo then begin
                IF DelOrder.Get(OrderNo) and (DelOrder."Order Type Option" <> 4) THEN BEGIN
                    if PosTrans.Get(OrderNo) then begin

                        if NOT ParameterC.get('ROBOT', 'VALIDAR') then
                            if not GetUsePost(InUseOnPos, PosTrans) then begin
                                Message(StrSubstNo(TEXT003, OrderNo, PosTrans."POS Terminal No."));
                                exit;
                            end;

                        if NOT prv.get('ROBOT', 'PRINTVAL') then begin
                            if PosTrans.Get(OrderNo) and (PosTrans."FSN Assigned PosTerminalNo" = '') or (PosTrans."FSN Status Robot" <> PosTrans."FSN Status Robot"::Procesado) then begin

                                if PosTrans."FSN Assigned PosTerminalNo" <> '' then
                                    if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                        //se actualiza el panel
                                        POSMenulineTemp.Init();
                                        POSMenulineTemp."Profile ID" := 'FASANI';
                                        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                        POSMenulineTemp.Description := 'Reiniciar';
                                        HospiPOSStartup.run(POSMenulineTemp);

                                        //se muestra mensaje si el pedido ya fue procesado
                                        Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                    end;

                                POSSESSION.SetValue('ROBOTORDEREDIT', 'TRUE');
                                Process(PosTrans, '');
                                POSSESSION.SetValue('ROBOTORDEREDIT', '');
                            end else begin
                                if OrderNo <> '' then begin
                                    if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                        //se actualiza el panel
                                        POSMenulineTemp.Init();
                                        POSMenulineTemp."Profile ID" := 'FASANI';
                                        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                        POSMenulineTemp.Description := 'Reiniciar';
                                        HospiPOSStartup.run(POSMenulineTemp);

                                        //se muestra mensaje si el pedido ya fue procesado
                                        Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                    end;
                                end;
                            end;
                        end else begin
                            if PosTrans.Get(OrderNo) and (PosTrans."FSN Assigned PosTerminalNo" = '') then begin

                                POSSESSION.SetValue('ROBOTORDEREDIT', 'TRUE');
                                Process(PosTrans, '');
                                POSSESSION.SetValue('ROBOTORDEREDIT', '');
                            end else begin
                                if OrderNo <> '' then begin
                                    if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                        //se actualiza el panel
                                        POSMenulineTemp.Init();
                                        POSMenulineTemp."Profile ID" := 'FASANI';
                                        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                        POSMenulineTemp.Description := 'Reiniciar';
                                        HospiPOSStartup.run(POSMenulineTemp);

                                        //se muestra mensaje si el pedido ya fue procesado
                                        Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                    end;
                                end;
                            end;
                        end;
                    end;
                END ELSE BEGIN
                    IF PosTrans.Get(OrderNo) THEN BEGIN

                        if not GetUsePost(InUseOnPos, PosTrans) then begin
                            Message(StrSubstNo(TEXT003, OrderNo, PosTrans."POS Terminal No."));
                            exit;
                        end;


                        if (PosTrans."FSN Assigned PosTerminalNo" = '') or (PosTrans."FSN Status Robot" <> PosTrans."FSN Status Robot"::Procesado) then
                            UpdateTerminal(PosTrans, 0, POSSESSION.TerminalNo())
                        ELSE BEGIN
                            if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                //se actualiza el panel
                                POSMenulineTemp.Init();
                                POSMenulineTemp."Profile ID" := 'FASANI';
                                POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                POSMenulineTemp.Description := 'Reiniciar';
                                HospiPOSStartup.run(POSMenulineTemp);

                                //se muestra mensaje si el pedido ya fue procesado
                                Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                            end;
                        END;
                    END;
                END;
            end;

            if FSNParameter.get('ROBOT', 'SALES') then
                if FSNParameter.Activo then begin//20260615
                    ProcessOrderSales(OrderNo);
                end;


        END;

        if POSMenuLine.Command = 'PRINTBILLEXT' then begin
            OrderNo := POSCtrl.GetDataGridKeyValue(POSCtrl.ActiveDataGrid);
            if FSNParameterRT.Get('ROBOT', 'PROCESSCALL') AND FSNParameterRT.Activo then begin
                if FSNParameter.get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
                    IF DelOrder.Get(OrderNo) THEN BEGIN
                        if (DelOrder."Order Type Option" <> 4) then begin
                            if NOT prv.get('ROBOT', 'PRINTVAL') then begin
                                if ValidateAsigTerminal(OrderNo) then begin
                                    PrintSlipRobot(DelOrder."Order No.");
                                    if DOrder.get(DelOrder."Order No.") then
                                        if not DOrder."Printed OK" then begin
                                            DOrder."Printed OK" := TRUE;
                                            DOrder.Modify();
                                        end;
                                end;
                            end else begin
                                PrintSlipRobot(DelOrder."Order No.");
                                if DOrder.get(DelOrder."Order No.") then
                                    if not DOrder."Printed OK" then begin
                                        DOrder."Printed OK" := TRUE;
                                        DOrder.Modify();
                                    end;
                            end;
                        end else begin
                            PrintSlipRobot(DelOrder."Order No.");
                            if DOrder.get(DelOrder."Order No.") then
                                if not DOrder."Printed OK" then begin
                                    DOrder."Printed OK" := TRUE;
                                    DOrder.Modify();
                                end;
                        end;
                    end;
                end;
            end else begin
                if FSNParameterRT.Get('ROBOT', 'SALES') THEN
                    IF FSNParameterRT.Activo THEN BEGIN
                        IF DelOrder.Get(OrderNo) THEN BEGIN
                            if (DelOrder."Order Type Option" <> 4) then begin
                                if NOT prv.get('ROBOT', 'PRINTVAL') then begin
                                    if ValidateAsigTerminal(OrderNo) then begin
                                        PrintSlipRobot(DelOrder."Order No.");
                                        if DOrder.get(DelOrder."Order No.") then
                                            if not DOrder."Printed OK" then begin
                                                DOrder."Printed OK" := TRUE;
                                                DOrder.Modify();
                                            end;
                                    end;
                                END else begin
                                    PrintSlipRobot(DelOrder."Order No.");
                                    if DOrder.get(DelOrder."Order No.") then
                                        if not DOrder."Printed OK" then begin
                                            DOrder."Printed OK" := TRUE;
                                            DOrder.Modify();
                                        end;
                                END;
                            END ELSE BEGIN
                                PrintSlipRobot(DelOrder."Order No.");
                                if DOrder.get(DelOrder."Order No.") then
                                    if not DOrder."Printed OK" then begin
                                        DOrder."Printed OK" := TRUE;
                                        DOrder.Modify();
                                    end;
                            END;
                        end;
                    end;
            end;

            if POSMenuLine.Command = 'PREF_ROBOT' then begin
                if FSNParameter.get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
                    if PosTrans.get(POSTransC.GetReceiptNo()) then begin
                        Process(PosTrans, '');
                    end;
                end;
            end;

            if POSMenuLine.Command = 'MARKROBOT' then begin
                if FSNParameter.get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
                    if PosTrans.get(POSTransC.GetReceiptNo()) then begin
                        ModifyStatusLine(PosTrans."Receipt No.", true);

                        POSMenulineTemp.Init();
                        POSMenulineTemp."Profile ID" := 'FASANI';
                        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                        POSMenulineTemp.Description := 'Reiniciar';
                        HospiPOSStartup.run(POSMenulineTemp);
                    END;
                end;
            end;
        END;
    END;

    procedure ValidateAsigTerminal(OrderNo: Code[20]): Boolean
    var
        POSTrans: Record "LSC POS Transaction";
        TEXT003: Label 'El pedido N.º %1 fue impreso en el N.º %2.';
    begin
        if POSTrans.get(OrderNo) then begin
            if POSTrans."FSN Assigned PosTerminalNo" = '' then begin
                POSTrans."FSN Assigned PosTerminalNo" := POSSESSION.TerminalNo();
                POSTrans.Modify();
                exit(true);
            end else begin
                if POSTrans."FSN Assigned PosTerminalNo" = POSSESSION.TerminalNo() then
                    exit(true)
                else begin
                    Message(StrSubstNo(TEXT003, OrderNo, POSTrans."FSN Assigned PosTerminalNo"));
                    exit(false);
                end;
            end;

        end;
    end;

    procedure GetInfocodePrintTerminal(xPOStemp: Record "LSC POS Transaction"; var Terminal: Code[10])
    var
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin
        InfoEntry.Reset();
        InfoEntry.SetRange("Receipt No.", xPOStemp."Receipt No.");
        InfoEntry.SetRange("Transaction Type", 0);
        InfoEntry.SetRange("Line No.", 75);
        if InfoEntry.FindFirst() then
            Terminal := InfoEntry.Information
        else
            Terminal := '';

    end;

    procedure ModifyStatusLine(ReceiptNo: Code[20]; StatusConf: Boolean)
    var
        myInt: Integer;
        POSLine: Record "LSC POS Trans. Line";
    begin
        POSLine.Reset();
        POSLine.SetRange(POSLine."Receipt No.", ReceiptNo);
        POSLine.SetRange(POSLine."Entry Type", POSLine."Entry Type"::Item);
        POSLine.SetRange(POSLine."Entry Status", POSLine."Entry Status"::" ");
        IF POSLine.Find('-') THEN BEGIN
            repeat
                if StatusConf then begin
                    if not (POSLine."FSN Additional Action" in [POSLine."FSN Additional Action"::ConfirmRobot]) then begin
                        POSLine."FSN Additional Action" := POSLine."FSN Additional Action"::ConfirmScann;
                        POSLine.Modify();
                    end;
                end else
                    if not (POSLine."FSN Additional Action" in [POSLine."FSN Additional Action"::Nothing]) then begin
                        POSLine."FSN Additional Action" := POSLine."FSN Additional Action"::Nothing;
                        POSLine.Modify();
                    end;
            until POSLine.Next() = 0;
        END;
    end;

    procedure ValGUIDRobot(PosTrans: Record "LSC POS Transaction"; var POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry"): Boolean
    var
    begin
        POSTransInfocodeEntry.Reset();
        POSTransInfocodeEntry.SetRange("Receipt No.", PosTrans."Receipt No.");
        POSTransInfocodeEntry.SetRange("Transaction Type", POSTransInfocodeEntry."Transaction Type"::"Sales Entry");
        POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry.Infocode, 'GUIDROBOT');
        if POSTransInfocodeEntry.FindFirst() then
            exit(true);
        exit(false);
    end;

    local procedure ToggleGiftReceiptOnPOSLines(var POSTransLine: Record "LSC POS Trans. Line"; GlobalRec: Record "LSC POS Menu Line")
    var
        MarkLines: Boolean;
        TXT_MARKED: Label 'Marked for Gift Receipt';
        TXT_UNMARKED: Label 'Unmarked for Gift Receipt';
    begin
        if not POSTransLine.IsEmpty then begin
            POSTransLine.SetRange("Marked for Gift Receipt", false);
            MarkLines := not POSTransLine.IsEmpty;
            POSTransLine.SetRange("Marked for Gift Receipt");
            POSTransLine.FindSet;
            POSTransLine.ModifyAll("Marked for Gift Receipt", MarkLines);
            if MarkLines then
                GlobalRec."Current-Description" := TXT_MARKED
            else
                GlobalRec."Current-Description" := TXT_UNMARKED;
        end;
    end;

    procedure Process(var ProPosTrans: Record "LSC POS Transaction"; TerminalNo: Code[10])
    var
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        //IDSelected: Option "","Ventanilla 1","Ventanilla 2","Ventanilla 3","Ventanilla 4";
        IDSelected: Integer;
        lTextMenu: Label '&Ventanilla 1,&Ventanilla 2,&Ventanilla 3,&Ventanilla 4';
        ConfirmText: Label 'Esta seguro de recibir en %1';
        TEXT000: Label 'Debe selecionar ventanilla';
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        json: JsonObject;
        Result: Text;
        CodResult: Integer;
        ErrorText: text;
        i: Integer;
        TextMenu: Text;
        TEXT001: Label 'Debe especificar el número de ventanillas en parámetro FSN, campo "Port 2".';
        TEXT002: Label 'El numero de ventanilla especificada en el campo Tiempo de espera es mayor al número de ventanillas configuradas en parámetro FSN, campo "Port 2".';
        TEXT003: Label 'No hay productos para procesar (estado del prod debe ser pendiente de escaneo) %1';
        DelOrder: Record "LSC Delivery Order";
        FSNParameter: Record "FSN Parameter";
        ValVentAut: Boolean;
        Lower: Integer;
        Upper: Integer;
        RemissionNo: Code[20];
        ValueLine: Boolean;
    begin
        i := 0;
        ValVentAut := false;
        IDSelected := 0;
        /*if FSNParameter.get('ROBOT', 'PROCESS') and (FSNParameter."Port 2" <> 0) then begin
            WHILE i < FSNParameter."Port 2" DO BEGIN
                i += 1;
                if TextMenu <> '' then
                    TextMenu += ',';
                TextMenu += '&Ventanilla' + ' ' + Format(i);
            END;
        end else
            Error(TEXT001);*/

        //Muestra el listado de ventanillas, por defecto esta selecionada ventanilla 1
        /*IDSelected := STRMENU(TextMenu, 1);

        if IDSelected = 0 then
            Error(TEXT000);*/

        //se reconfirma si se esta seguro de la ventanilla selecionada.
        //if Confirm(StrSubstNo(ConfirmText, Format(IDSelected))) then begin

        GetInfocode(ProPosTrans, IDSelected);

        if IDSelected = 0 then begin

            if DelOrder.Get(ProPosTrans."Receipt No.") then begin
                //ValVentAut := true
                FSNParameter.reset;
                FSNParameter.SetRange(FSNParameter.Grupo, 'ROBOTTERMINAL');
                FSNParameter.SetRange(FSNParameter.Codigo, POSSESSION.TerminalNo());
                FSNParameter.SetRange(FSNParameter.Activo, true);
                if FSNParameter.FindFirst() then begin
                    if FSNParameter."Port" <> 0 then begin
                        IDSelected := FSNParameter."Port";
                        ValVentAut := false;
                    end else
                        ValVentAut := true;
                end else
                    ValVentAut := true;
            end else begin
                FSNParameter.reset;
                FSNParameter.SetRange(FSNParameter.Grupo, 'ROBOTTERMINAL');
                FSNParameter.SetRange(FSNParameter.Codigo, POSSESSION.TerminalNo());
                FSNParameter.SetRange(FSNParameter.Activo, true);
                if FSNParameter.FindFirst() then begin
                    if FSNParameter."Port" <> 0 then begin
                        IDSelected := FSNParameter."Port";
                        ValVentAut := false;
                    end else
                        ValVentAut := true;
                end else
                    ValVentAut := true;
            end;

            //en el campo "Port 2" se especifica el numero de ventanillas configuradas
            //en limit value se guarda la ultima ventanilla seleccionada y hace un ingremento para la siguiente seleccion
            //se evalua si llego al limite de ventanillas configuradas para reiniciar el conteo
            if ValVentAut then
                if FSNParameter.get('ROBOT', 'PROCESS') then begin
                    IsLastWithinRange(FSNParameter."Value Text 2", Lower, Upper);
                    //en el campo timeout se especifica la ventanilla a seleccionar manualmente, si es 0 se selecciona automaticamente
                    if (Lower <> 0) and (Upper <> 0) then begin

                        if FSNParameter."Port 2" = 0 then
                            error(TEXT001);

                        if (FSNParameter."Limit Value" <> 0)
                            and not (FSNParameter."Limit Value" > Upper) then begin
                            IDSelected := FSNParameter."Limit Value";
                            FSNParameter."Limit Value" += 1;
                            FSNParameter.Modify();
                            Commit();
                        end else begin
                            IDSelected := Lower;
                            FSNParameter."Limit Value" := Lower;
                            FSNParameter.Modify();
                            Commit();
                        end;
                    end else begin
                        if Lower > FSNParameter."Port 2" then
                            error(TEXT002)
                        else
                            IDSelected := Lower;
                    end;
                end;
        end;

        //se actualiza la terminal
        if DelOrder.Get(ProPosTrans."Receipt No.") then
            UpdateTerminal(ProPosTrans, IDSelected, TerminalNo);

        IF ProPosTrans.Get(ProPosTrans."Receipt No.") THEN;

        //se ejecuta el comando 'HOSP-SEARCHRESET' para actualizar el panel
        POSMenulineTemp.Init();
        POSMenulineTemp."Profile ID" := 'FASANI';
        POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
        POSMenulineTemp.Description := 'Reiniciar';
        HospiPOSStartup.run(POSMenulineTemp);

        //creacio de JSON que se enviara al robot
        json.Add('receipt', ProPosTrans."Receipt No.");
        json.Add('posTerminal', ProPosTrans."POS Terminal No.");
        json.Add('deliveryWindow', IDSelected);
        if DelOrder.Get(ProPosTrans."Receipt No.") then begin
            json.Add('isPriority', false);
            json.Add('productDetail', getProductList(ProPosTrans, ValueLine));
        end else begin
            json.Add('isPriority', true);
            json.Add('productDetail', getProductListPref(ProPosTrans, ValueLine));
        end;

        //Se guarda la solicitud segun la configuracion en Parametros FSN
        Save(ProPosTrans."Receipt No.", Format(json), true);

        if ValueLine then begin
            Result := SentInfotmationRobot(Format(json), ProPosTrans."Receipt No.", CodResult, ErrorText);

            //Repuesta exitosa.
            if CodResult = 200 then begin
                //Se guarda la repuesta segun la configuracion en Parametros FSN
                Save(ProPosTrans."Receipt No.", Result, false);

                //Guarda numero de ventallia selecionada en infocde
                SaveInfocode(ProPosTrans, FORMAT(IDSelected), 60);

                //se actualizan las lineas segun la repuesta del robot
                UpdatePosTransLine(Result, ProPosTrans, false);
            end else begin
                if Result = '{}' then
                    Message(ErrorText)
                else begin
                    //Se guarda el mensaje de error segun la configuracion en Parametros FSN
                    Save(ProPosTrans."Receipt No.", Result, false);
                    Message(Result);
                end
            end;
        end else begin
            IF POSSESSION.GetValue('ROBOTORDEREDIT') <> 'TRUE' THEN
                Message(StrSubstNo(TEXT003), ProPosTrans."Receipt No.");
            POSSESSION.SetValue('ROBOTORDEREDIT', '');
        end;
    end;

    procedure IsLastWithinRange(RangeText: Text[50]; var Lower: Integer; var Upper: Integer)
    var
        DotPos: Integer;
        LeftPart: Text[50];
        RightPart: Text[50];
        TEXT000: Label 'Formato de rango inválido. Debe ser "min..max".';
        TEXT001: Label 'Límite inferior inválido en el rango: %1';
        TEXT002: Label 'Límite superior inválido. Debe especificarse el límite superior.';
        TEXT003: Label 'Límite superior inválido en el rango: %1';
        TEXT004: Label 'Rango inválido: el límite inferior (%1) es mayor que el superior (%2).';
    begin

        // Buscar la posición de ".."
        DotPos := StrPos(RangeText, '..');
        if DotPos = 0 then begin
            Evaluate(Lower, RangeText);
            exit;
        end;

        // Extraer partes izquierda y derecha
        LeftPart := CopyStr(RangeText, 1, DotPos - 1);
        RightPart := CopyStr(RangeText, DotPos + 2);

        // Evaluar límite inferior (si está vacío se asume 0)
        if LeftPart = '' then
            Lower := 1
        else begin
            if not Evaluate(Lower, LeftPart) then
                Error(StrSubstNo(TEXT001, LeftPart));
        end;

        // Evaluar límite superior (debe existir)
        if RightPart = '' then
            Error(TEXT002);
        if not Evaluate(Upper, RightPart) then
            Error(StrSubstNo(TEXT003, RightPart));

        // Valida el rango
        if Lower > Upper then
            Error(StrSubstNo(TEXT004, Lower, Upper));
    end;

    procedure UpdateTerminal(var ProPosTrans: Record "LSC POS Transaction"; WindowsSelected: Integer; TerminalNo: Code[10])
    var
        myInt: Integer;
        Terminal: Code[10];
    begin
        if TerminalNo <> '' then
            Terminal := TerminalNo
        else
            Terminal := POSSESSION.TerminalNo();
        if ProPosTrans."POS Terminal No." <> Terminal then
            UpdateTransactionTerminal(ProPosTrans."Receipt No.", Terminal, WindowsSelected)
        else begin
            // se asigna el pedido a que pv se proceso y se actualiza a estado procesado
            ProPosTrans."FSN Assigned PosTerminalNo" := Terminal;
            ProPosTrans."FSN Status Robot" := ProPosTrans."FSN Status Robot"::Procesado;
            ProPosTrans."Staff ID" := POSSESSION.StaffID();
            ProPosTrans."FSN state of preparation" := ProPosTrans."FSN state of preparation"::Preparando;
            if WindowsSelected <> 0 then
                ProPosTrans."FSN Ventanilla" := WindowsSelected;
            ProPosTrans.Modify(true);
        end;
    end;

    procedure UpdateTerminalAut(var ProPosTrans: Record "LSC POS Transaction")
    var
        myInt: Integer;
        Terminal: Code[10];
    begin
        Terminal := POSSESSION.TerminalNo();
        if ProPosTrans."POS Terminal No." <> Terminal then
            UpdateTransactionTerminalAut(ProPosTrans."Receipt No.", Terminal)
        else begin
            // se asigna el pedido a que pv se proceso y se actualiza a estado procesado
            ProPosTrans."FSN Assigned PosTerminalNo" := Terminal;
            ProPosTrans."FSN Status Robot" := ProPosTrans."FSN Status Robot"::Procesado;
            ProPosTrans."Staff ID" := POSSESSION.StaffID();
            ProPosTrans."FSN state of preparation" := ProPosTrans."FSN state of preparation"::Preparando;
            ProPosTrans.Modify(true);
        end;
    end;

    //Guarda la ventallia selecionada en infocde
    local procedure SaveInfocode(xPOStemp: Record "LSC POS Transaction"; Information: text; LineNo: integer)
    var
        myInt: Integer;
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
        TEXT000: Label 'Despacho Ventanilla %1';
    begin
        InfoEntry.Init();
        InfoEntry."Store No." := xPOStemp."Store No.";
        InfoEntry."POS Terminal No." := xPOStemp."POS Terminal No.";
        InfoEntry."Receipt No." := xPOStemp."Receipt No.";
        InfoEntry."Transaction Type" := 0;
        InfoEntry."Line No." := LineNo;
        InfoEntry.Infocode := 'TEXT';
        InfoEntry.Information := Information;
        InfoEntry.Date := Today;
        InfoEntry.Time := Time;
        if not InfoEntry.Insert() then
            InfoEntry.Modify();

        //Inserta el freeText en pos trans Line para mostrar en el pos
        addLine(xPOStemp, StrSubstNo(TEXT000, Information));
    end;

    procedure addLine(
        transaction: Record "LSC POS Transaction";
        description: Text)
    var
        transLine: Record "LSC POS Trans. Line";
    begin

        transLine.Init();
        transLine.Validate("Receipt No.", transaction."Receipt No.");
        transLine.Validate("Store No.", transaction."Store No.");
        transLine.Validate("POS Terminal No.", transaction."POS Terminal No.");
        transLine.Validate("Line No.", 60);
        //transLine.Validate("Line No.", getLine(transaction, 'new'));
        transLine.Validate("Entry Type", transLine."Entry Type"::FreeText);
        transLine.Validate("Description", description);
        if not transLine.Insert(true) then
            transLine.Modify();
    end;

    //ultima line de la transaccion
    procedure getLine(transaction: Record "LSC POS Transaction"; type: text): Integer
    var
        transLine: Record "LSC POS Trans. Line";
    begin
        transLine.SetCurrentKey("Receipt No.", "Line No.");
        transLine.SetRange("Receipt No.", transaction."Receipt No.");
        case type of
            'new':
                begin
                    if transLine.FindLast() then
                        exit(transLine."Line No." + 10000)
                    else
                        exit(10000);
                end;
        end;
    end;

    //Optiene array de las lineas de la transaccion.
    procedure getProductList(POSTransaction: Record "LSC POS Transaction"; var BooleanVal: Boolean): JsonArray
    var
        POSTransLine: Record "LSC POS Trans. Line";
        array: JsonArray;
        json: JsonObject;
        value: JsonValue;
        BarcodeNo: Code[10];
        QuantityInt: Integer;
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        Qty: Decimal;
    begin
        BooleanVal := false;

        POSTransLine.Reset();
        POSTransLine.SetRange(POSTransLine."Store No.", POSTransaction."Store No.");
        POSTransLine.SetRange(POSTransLine."POS Terminal No.", POSTransaction."POS Terminal No.");
        POSTransLine.SetRange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange(POSTransLine."Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."FSN Additional Action" = POSTransLine."FSN Additional Action"::ConfirmScann then begin
                    Clear(json);
                    Clear(BarcodeNo);
                    json.Add('code', POSTransLine.Number);
                    json.Add('name', POSTransLine.Description);
                    json.Add('lineNo', POSTransLine."Line No.");
                    IF POSTransLine."Unit of Measure" = '' then begin
                        json.Add('packagingUnit', FilterUnitOfMeasure(POSTransLine.Number, POSTransLine."Barcode No."))
                    end else
                        json.Add('packagingUnit', POSTransLine."Unit of Measure");
                    if Evaluate(QuantityInt, format(POSTransLine.Quantity)) then;
                    json.Add('quantity', QuantityInt);
                    json.Add('isBox', FilterUnitOfMeasureBox(POSTransLine.Number, POSTransLine."Unit of Measure", POSTransLine."Barcode No.", Qty));
                    array.Add(json.AsToken());
                    BooleanVal := true;
                end;
            until POSTransLine.Next() = 0;

            POSMenulineTemp.Init();
            POSMenulineTemp."Profile ID" := 'FASANI';
            POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
            POSMenulineTemp.Description := 'Reiniciar';
            HospiPOSStartup.run(POSMenulineTemp);

            exit(array);
        end;
    end;

    //Optiene array de las lineas de la transaccion de la prefactura
    procedure getProductListPref(POSTransaction: Record "LSC POS Transaction"; var BooleanVal: Boolean): JsonArray
    var
        POSTransLine: Record "LSC POS Trans. Line";
        array: JsonArray;
        json: JsonObject;
        value: JsonValue;
        BarcodeNo: Code[10];
        QuantityInt: Integer;
        Qty: Decimal;
    begin
        BooleanVal := false;

        POSTransLine.Reset();
        POSTransLine.SetRange(POSTransLine."Store No.", POSTransaction."Store No.");
        POSTransLine.SetRange(POSTransLine."POS Terminal No.", POSTransaction."POS Terminal No.");
        POSTransLine.SetRange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange(POSTransLine."Entry Type", POSTransLine."Entry Type"::Item);
        POSTransLine.SetRange(POSTransLine."Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."FSN Additional Action" = POSTransLine."FSN Additional Action"::ConfirmScann then begin

                    Clear(json);
                    Clear(BarcodeNo);
                    json.Add('code', POSTransLine.Number);
                    json.Add('name', POSTransLine.Description);
                    json.Add('lineNo', POSTransLine."Line No.");
                    IF POSTransLine."Unit of Measure" = '' then begin
                        json.Add('packagingUnit', FilterUnitOfMeasure(POSTransLine.Number, POSTransLine."Barcode No."))
                    end else
                        json.Add('packagingUnit', POSTransLine."Unit of Measure");
                    if Evaluate(QuantityInt, format(POSTransLine.Quantity)) then;
                    json.Add('quantity', QuantityInt);
                    json.Add('isBox', FilterUnitOfMeasureBox(POSTransLine.Number, POSTransLine."Unit of Measure", POSTransLine."Barcode No.", Qty));
                    array.Add(json.AsToken());
                    BooleanVal := true;
                END;

            until POSTransLine.Next() = 0;

            exit(array);
        end;

    end;


    //Filtra unidad de medida si se encuentra vacia en pos trans line
    procedure FilterUnitOfMeasure(ItemNo: Code[20]; Barcode: Code[20]): Code[10]
    var
        BarcodeTable: Record "LSC Barcodes";
    begin
        BarcodeTable.Reset();
        BarcodeTable.SetRange(BarcodeTable."Item No.", ItemNo);
        BarcodeTable.SetRange(BarcodeTable."Barcode No.", Barcode);
        if BarcodeTable.FindFirst() then
            exit(BarcodeTable."Unit of Measure Code");
    end;

    //valida si la unidad de medida es caja
    procedure FilterUnitOfMeasureBox(ItemNo: Code[20]; UnitofMeasureVal: Code[10]; Barcode: Code[22]; Qty: Decimal): Boolean
    var
        lItem: Record "Item";
        IUOM: Record "Item Unit of Measure";
        UnitofMeasure: Code[10];
    begin
        Qty := 0;
        if UnitofMeasureVal = '' then
            UnitofMeasure := FilterUnitOfMeasure(ItemNo, Barcode)
        else
            UnitofMeasure := UnitofMeasureVal;

        if lItem.get(ItemNo) then begin
            if IUOM.Get(ItemNo, UnitofMeasure) then
                if (UnitofMeasure = lItem."Purch. Unit of Measure") then begin
                    Qty := IUOM."Qty. per Unit of Measure";
                    exit(True);
                end else
                    exit(false);
        end;
    end;

    //Actualiza las lineas de producto, segun la repuesta del robot
    procedure UpdatePosTransLine(Response: Text; POSTransaction: Record "LSC POS Transaction"; NegPos: Boolean)
    var
        jObject: JsonObject;
        jToken: JsonToken;
        JsonArray: JsonArray;
        JsonItem: JsonObject;
        Message: text;
        POSTransLine: Record "LSC POS Trans. Line";
        FSNWSProcRobotJrn: Codeunit "FSN WS Process Robot Jrn";
        ErrorTextConfig: Text;
        ErrorTextAplyJnl: Text;
        ItemJrnTemplete: Record "Item Journal Template";
        ItemJrnBatch: Record "Item Journal Batch";
        ItemJrnLine: Record "Item Journal Line";
        UnitOfm: Code[10];
        TEXT001: Label 'Los datos ya se encuentran registrados en Item Ledger Entry.';
        TEXT002: label 'No se encontraron detalles de productos en la respuesta del robot exitosa.';
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        ItemLedgerEntry_l: Record "Item Ledger Entry";
        Qty: Decimal;
    begin
        Clear(ItemJrnLine);
        // Leer el JSON de entrada
        if jObject.ReadFrom(Response) then begin
            if jObject.Get('state', jToken) and not (JToken.AsValue().IsNull) then
                if jToken.AsValue().AsText() = '3' then begin
                    if jObject.Get('message', jToken) then
                        Message(jToken.AsValue().AsText());

                    //Imprime la comanda del robot
                    PrintSlipRobot(POSTransaction."Receipt No.");
                end else begin
                    //Valida cofiguracion en FSN Parameter y almacenes
                    if NOT FSNWSProcRobotJrn.ValidateConfigJnl(POSTransaction."Store No.", POSTransaction."Receipt No.", ItemJrnTemplete, ItemJrnBatch, ErrorTextConfig, NegPos) then;
                    if jObject.Get('productDetail', jToken) then //se Selecciona el arreglo
                        if jToken.IsArray then begin //se Verifica que el token es un arreglo y convertirlo
                            JsonArray := jToken.AsArray();

                            if JsonArray.Count = 0 then
                                ErrorTextConfig := TEXT002
                            else
                                foreach jToken in JsonArray do begin
                                    if jToken.IsObject then begin //se verificar que sea un objeto
                                        JsonItem := jToken.AsObject();

                                        Clear(POSMenuLineTemp);

                                        //filtra pos trans line
                                        POSTransLine.Reset();
                                        POSTransLine.SetCurrentKey("Receipt No.", "Line No.");
                                        POSTransLine.SetRange(POSTransLine."Receipt No.", POSTransaction."Receipt No.");

                                        if JsonItem.Get('code', jToken) then
                                            POSTransLine.SetRange(POSTransLine.Number, jToken.AsValue().AsText());

                                        if JsonItem.Get('lineNo', jToken) then
                                            POSTransLine.SetRange(POSTransLine."Line No.", jToken.AsValue().AsInteger());

                                        if POSTransLine.FindFirst() then begin
                                            if JsonItem.Get('isAccepted', jToken) then begin
                                                if jToken.AsValue().AsBoolean() then begin //si o  no es aceptado por el robot

                                                    if JsonItem.Get('packagingUnit', jToken) then
                                                        UnitOfm := jToken.AsValue().AsText();


                                                    POSMenuLineTemp.Init();
                                                    POSMenuLineTemp."Profile ID" := 'ROBOT';
                                                    POSMenuLineTemp."Current-RECEIPT" := POSTransLine."Receipt No.";
                                                    POSMenuLineTemp."Current-SALESORDER" := POSTransLine."Store No.";
                                                    POSMenuLineTemp."Menu ID" := POSTransLine.Number;
                                                    POSMenuLineTemp."Current-UOM" := UnitOfm;
                                                    POSMenuLineTemp."Key No." := POSTransLine."Line No.";
                                                    POSMenuLineTemp."Current-Price" := POSTransLine.Quantity;

                                                    IF FSNParameter.Get('ROBOT', 'PROCESS') THEN;
                                                    //se valida que no exista Jrn Line o si ya estan registrados en item ledger entry,  si no se crean la linea.
                                                    if not FSNWSProcRobotJrn.ValidateItemLedgerEntry(POSMenuLineTemp, ItemLedgerEntry_l, FSNParameter."Distribution Location Ext.", NegPos) then begin
                                                        if not FSNWSProcRobotJrn.ValidateExistJrnLine(ItemJrnLine, POSMenuLineTemp, ItemJrnBatch.Name) then
                                                            FSNWSProcRobotJrn.InsertLineAdjTUseItemJrnTemplate(ItemJrnLine, POSMenuLineTemp, ItemJrnTemplete, ItemJrnBatch, NegPos)//aplica ajuste negativo a la bodega del robot
                                                        else begin
                                                            if ItemJrnLine.Quantity <> POSMenuLineTemp."Current-Price" then begin
                                                                ItemJrnLine.VALIDATE(Quantity, POSMenuLineTemp."Current-Price");
                                                                ItemJrnLine.Modify();
                                                            end;
                                                        end;
                                                    end;
                                                    POSTransLine."FSN Additional Action" := POSTransLine."FSN Additional Action"::ConfirmRobot;
                                                end else
                                                    POSTransLine."FSN Additional Action" := POSTransLine."FSN Additional Action"::ConfirmSala;
                                                POSTransLine.Modify();
                                            end;
                                        end;
                                    end;
                                end;
                        end;

                    //recibe Item Journal line para aplcar el ajuste
                    if ErrorTextConfig = '' then begin // se valida si hay mensaje de error por la cofiguracion en FSN Parameter y almacenes
                        if not ItemJrnLine.IsEmpty then begin // se valida si existen registros retornados
                                                              //aplica el ajuste negativo a la bodega del robot
                            IF FSNParameter.Get('ROBOT', 'PROCESSJORNAL') AND FSNParameter.Activo THEN BEGIN
                                if not FSNWSProcRobotJrn.ProcessJnlPost(ItemJrnLine, ErrorTextAplyJnl) then
                                    Message(ErrorTextAplyJnl);
                            END;
                        end else
                            Message(TEXT001);
                    end else
                        Message(ErrorTextConfig);

                    //Imprime la comanda del robot
                    PrintSlipRobot(POSTransaction."Receipt No.");

                    //Muestra el mensaje de la API
                    if jObject.Get('message', jToken) then
                        Message('ROBOT:' + ' ' + jToken.AsValue().AsText());
                end;

        end;
    end;

    procedure SentInfotmationRobot(pBody: Text; Number: Code[20]; var CodeResultS: Integer; var MessageError: Text): Text
    var
        Parameters: DotNet Dictionary_Of_T_U;
        HttpResponseMessage: DotNet HttpResponseMessage;
        JArray: DotNet JArray;
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        p: Record "LSC POS Menu Line";
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        SRFREQUEST: Text;
        SRFBANVALUE: Text;
        OD: Codeunit "FSN OData Conexion";
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        response: JsonObject;
        token: JsonToken;
        File: DotNet File;
        responseText: Label '{"state": 3,"message": "ROBOT: Pedido Rechazado","productDetail": [{}]}';
    begin
        //CodeResultS := 200;
        //ResultText := File.ReadAllText('C:\temp\ResultRobot.txt');
        //exit(ResultText);
        //en FSN Parameter se valida si en el campo Port es 200 para devolver un resultado quemado
        IF FSNParameter.Get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
            if FSNParameter.Port = 200 then begin
                CodeResultS := 200;
                response.ReadFrom(responseText);  // convierte el texto en JsonObject
                exit(Format(response));
            end;
            BODYGLOBAL := pBody;
            SRFREQUEST := FSNParameter."Web Uri" + 'SendOrder';
            SRFBANVALUE := FSNParameter."Web Action";

            RESPONSEGLOBAL := '';
            //NEW
            body.WriteFrom(pBody);
            body.GetHeaders(contentHeader);
            contentHeader.Clear();
            contentHeader.Add('Content-Type', FSNParameter."Web Action");
            request.GetHeaders(requestHeader);
            requestHeader.Clear();
            request.Content := body;
            //requestheader.Add('Authorization', 'Bearer ' + TokenV);

            response := Post(SRFREQUEST, request, CodeResultS, MessageError);
            exit(Format(response));
        end;
    end;

    //optiene el locker asignado al pedido CC
    procedure GetLooker(OrderNo: Code[20]; var CodeResultS: Integer; var ResponseText: Text)
    var
        SRFREQUEST: Text;
        request: HttpRequestMessage;
        SRFBANVALUE: Text;
        MessageError: Text;
        response: JsonObject;
        URLText: Label 'GetOrderLocker?orderNo=%1';
    begin

        IF FSNParameter.Get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
            SRFREQUEST := FSNParameter."Web Uri" + StrSubstNo(URLText, OrderNo);//Arma la URL
            SRFBANVALUE := FSNParameter."Web Action";

            response := Get(SRFREQUEST, request, CodeResultS, MessageError, ResponseText);//consulta el BOX asignado al pedido

        end;

    end;


    procedure Get(Uri: Text; request: HttpRequestMessage; var CodeResult: Integer; var ErrorMessage: Text; var ResponseText: Text): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
        ErrorText: Label 'Los datos no representan un token válido de JSON.: %1';
    begin
        CodeResult := 0;
        ErrorMessage := '';
        ResponseText := '';

        request.Method := 'GET';
        request.SetRequestUri(Uri);

        client.Send(request, response);
        status := response.HttpStatusCode;
        CodeResult := status;

        response.Content.ReadAs(res);
        ResponseText := res; // <-- aquí ya se pueden leer la respuesta aunque no sea JSON
        IF CodeResult <> 200 THEN
            if not response.IsSuccessStatusCode() then begin
                ErrorMessage := 'Error HTTP ' + Format(status) + ': ' + res;
                exit(jResponse); // se devuelve vacío
            end;
    end;

    //Imprime la comanda de robot
    local procedure PrintSlipRobot(TransCC: Code[20]): Boolean
    var
        POSTrans: Record "LSC POS Transaction";
        xPosTrLines: Record "LSC POS Trans. Line";
        xStore: Record "LSC Store";
        rDeliveryOrder: Record "LSC Delivery Order";
        xDireccion: Text[250];
        xItem: Record "Item";
        xNewText: Text[50];
        xInt: Integer;
        xToInt: Integer;
        xStrFrom: Integer;
        xFreeText: Text;
        PosFunc: codeunit "LSC POS Functions";
        Tray: Integer;
        HoraEntrega: Time;
        xInfoCodeEntry: Record "LSC POS Trans. Infocode Entry";
        xStaff: Record "LSC Staff";
        FSNUtil: Codeunit "FSN Utility";
        TCommand, TransactorText, Tresponse, Response_Text : Text;
        countDescription: Integer;
        DSTR1: Text[80];
        Value: array[10] of Text[250];
        IsDeliveryCopy: Boolean;
        rBarras: Record "LSC Barcodes";
        POSMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        DelOrdr: Record "LSC Delivery Order";
        myInt: Integer;
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
        CodeResultS: Integer;
        ResponseText: Text;
        DeliveryContactAddress: Record "LSC Delivery Contact Address";
    begin

        DelOrdr.Reset();
        if DelOrdr.Get(TransCC) then
            if (DelOrdr."Printed OK" = false) then begin
                DelOrdr."Printed OK" := true;
                DelOrdr.Modify(true);
            end;

        Clear(xDireccion);
        countDescription := 0;
        POSTrans.reset;
        if POSTrans.get(TransCC) then begin
            PosFunc.InitPosFunctions;
            PosFunc.PosTransDiscLoad(POSTrans."Receipt No.");
            Clear(PrintUtil);
            if not PrintUtil.OpenReceiptPrinter(2, 'PR', '', 0, POSTrans."Receipt No.") then
                exit(false);

            Tray := 2;
            HoraEntrega := POSTrans."Trans Time" + (30 * (60 * 1000));
            CLEAR(Value);
            DSTR1 := '#C######################################';
            Value[1] := 'Hora Entrega';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, false, FALSE, FALSE));

            DSTR1 := '#C######################################';
            Value[1] := '';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            DSTR1 := '#C######################################';
            Value[1] := '***** HORA SUGERIDA:' + FORMAT(HoraEntrega, 0, '<Hours12>:<Minutes,2>:<Seconds,2><Second dec.> <AM/PM>') + ' *****';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            PrintUtil.PrintSeperator(Tray);

            DSTR1 := '#L######################################';
            // Pedido
            Value[1] := 'PEDIDO: ' + COPYSTR(POSTrans."Receipt No.", 11);
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            if delOrdr.Get(TransCC) then begin

                InfoEntry.Reset();
                InfoEntry.SetRange(InfoEntry."Store No.", POSTrans."Store No.");
                InfoEntry.SetRange(InfoEntry."POS Terminal No.", POSTrans."POS Terminal No.");
                InfoEntry.SetRange(InfoEntry."Receipt No.", POSTrans."Receipt No.");
                InfoEntry.SetRange(InfoEntry.Infocode, 'TEXT');
                InfoEntry.SetRange(InfoEntry."Line No.", 80);
                if InfoEntry.FindFirst() then begin
                    //GetLooker(TransCC, CodeResultS, ResponseText);
                    DSTR1 := '#L######################################';
                    Value[1] := 'BOX: ' + COPYSTR(InfoEntry.Information, 1, 30);
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;
            end;

            DSTR1 := '#L######################################';
            // Ventanilla

            InfoEntry.Reset();
            InfoEntry.SetRange(InfoEntry."Store No.", POSTrans."Store No.");
            InfoEntry.SetRange(InfoEntry."POS Terminal No.", POSTrans."POS Terminal No.");
            InfoEntry.SetRange(InfoEntry."Receipt No.", POSTrans."Receipt No.");
            InfoEntry.SetRange(InfoEntry.Infocode, 'TEXT');
            InfoEntry.SetRange(InfoEntry."Line No.", 60);
            if InfoEntry.FindFirst() then begin
                Value[1] := 'VENTANILLA: ' + COPYSTR(InfoEntry.Information, 1, 30);
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            end;

            // Linea de Farmacia
            IF xStore.GET(POSTrans."Store No.") THEN
                Value[1] := 'FASANI: ' + xStore.Name
            ELSE
                Value[1] := 'FASANI: ____________________';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Linea de Cliente
            Value[1] := 'Cliente ID: ' + POSTrans."Sell-to Contact No.";
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Nombre de Cliente
            Value[1] := 'Cliente: ' + COPYSTR(POSTrans.Comment, 1, 31);
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            // Direccion de Entrega
            CLEAR(xInfoCodeEntry);
            xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(Infocode, 'DADDRESS2');
            IF xInfoCodeEntry.FIND('-') THEN BEGIN
                Value[1] := 'Area: ' + COPYSTR(xInfoCodeEntry.Information, 1, 30);
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            IF rDeliveryOrder.GET(POSTrans."Receipt No.") THEN BEGIN
                IF rDeliveryOrder.Address <> '' THEN BEGIN
                    xStrFrom := 1;
                    xFreeText := 'Calle/Col.: ' + rDeliveryOrder.Address;
                    xToInt := (STRLEN(xFreeText) DIV 38) + 1;
                    FOR xInt := 1 TO xToInt DO BEGIN
                        xNewText := COPYSTR(xFreeText, 1, 38);

                        Value[1] := xNewText;
                        IF xInt > 1 THEN
                            Value[1] := '  ' + xNewText;

                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        xFreeText := COPYSTR(xFreeText, 39);
                    END;
                END;
                IF rDeliveryOrder."Grid Code" <> '' THEN BEGIN
                    Value[1] := 'Zona: ' + rDeliveryOrder."Grid Code";
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                END;

                if rDeliveryOrder."FSN Directions" <> '' then begin
                    xDireccion := rDeliveryOrder."FSN Directions";

                end;
            END;

            IF xDireccion = '' then
                xDireccion := '______________________________________';


            if delOrdr.Get(TransCC) then begin
                IF xDireccion <> '______________________________________' THEN BEGIN
                    DeliveryContactAddress.Reset();
                    DeliveryContactAddress.SetRange(DeliveryContactAddress."Phone No.", delOrdr."Phone No.");
                    DeliveryContactAddress.SetRange(DeliveryContactAddress."Address 2", delOrdr."Address 2");
                    if DeliveryContactAddress.FindFirst() then
                        if DeliveryContactAddress."FSN Direction" <> '' then
                            xDireccion := xDireccion + ', ' + DeliveryContactAddress."FSN Direction";
                END;
            end;

            // Imprimir direccion fragmentada:
            xFreeText := 'Direccion: ' + xDireccion;

            xToInt := (STRLEN(xFreeText) DIV 30) + 1;
            FOR xInt := 1 TO xToInt DO BEGIN
                xNewText := COPYSTR(xFreeText, 1, 30);

                Value[1] := xNewText;
                IF xInt > 1 THEN
                    Value[1] := '  ' + xNewText;

                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                xFreeText := COPYSTR(xFreeText, 31);
            END;

            // Caja y Vendedor
            DSTR1 := 'CAJA: 999 VENDEDOR: 12345678901234567890';
            DSTR1 := '#L####### #L############################';
            //Value[1] := 'Caja: ' + COPYSTR(POSTrans."POS Terminal No.", 4, 3);
            Value[1] := 'Caja: ' + COPYSTR(POSSESSION.TerminalNo(), 4, 3);
            IF xStaff.GET(POSTrans."Staff ID") THEN
                Value[2] := 'Vendedor: ' + COPYSTR(xStaff."Name on Receipt", 1, 20)
            ELSE
                Value[2] := 'Vendedor: ' + '____________________';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

            xInfoCodeEntry.Reset();
            xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(Infocode, 'TEXT');
            xInfoCodeEntry.SETRANGE("Line No.", 70);
            if xInfoCodeEntry.Find('-') then
                repeat
                    DSTR1 := '#L######################################';
                    Value[1] := 'Terminal: ' + xInfoCodeEntry.Information;
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                until xInfoCodeEntry.Next() = 0;

            xInfoCodeEntry.Reset();
            xInfoCodeEntry.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(Infocode, 'TEXT');
            xInfoCodeEntry.SETRANGE("Line No.", 80);
            if xInfoCodeEntry.Find('-') then
                repeat
                    DSTR1 := '#L######################################';
                    Value[1] := 'Ubicación: ' + xInfoCodeEntry.Information;
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                until xInfoCodeEntry.Next() = 0;

            DSTR1 := '#L######################################';
            PrintUtil.PrintSeperator(Tray);

            POSTrans.CALCFIELDS(Payment);
            IF POSTrans.Payment <> 0 THEN BEGIN
                xPosTrLines.RESET;
                xPosTrLines.SETCURRENTKEY("Receipt No.", "Entry Type", "Entry Status");
                xPosTrLines.SETRANGE(xPosTrLines."Receipt No.", POSTrans."Receipt No.");
                xPosTrLines.SETRANGE(xPosTrLines."Entry Type", xPosTrLines."Entry Type"::Payment);
                xPosTrLines.SETRANGE(xPosTrLines."Entry Status", 0);
                if xPosTrLines.Find('-') then
                    repeat
                        //DSTR1 := '#L####### #L############################';
                        DSTR1 := '#L######################################';
                        Value[1] := COPYSTR(xPosTrLines.Description, 1, 20) + '.';
                        IF xPosTrLines.Number = '1' THEN begin
                            DSTR1 := '#L####### #L############################';
                            Value[2] := '$' + Format(xPosTrLines.Amount);
                        end;
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    until xPosTrLines.Next() = 0;

                DSTR1 := '#L######################################';
                Value[1] := 'Venta :$' + FORMAT(POSTrans.Payment, 0, '<Precision,2:2><Standard Format,2>');
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                Value[1] := FSNUtil.Num2Text(ABS(POSTrans.Payment)) + ' ' + 'DOLARES';
                DSTR1 := '#L######################################';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            END;

            PrintUtil.PrintSeperator(Tray);

            DSTR1 := '#L######################################';
            CLEAR(xPosTrLines);
            xPosTrLines.RESET;
            xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::Item);
            xPosTrLines.SETRANGE(xPosTrLines."FSN Additional Action", xPosTrLines."FSN Additional Action"::ConfirmRobot);
            xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
            IF xPosTrLines.FIND('-') THEN BEGIN
                DSTR1 := '#C######################################';
                Value[1] := '----------- PROCESO AUTOMÁTICO ------------';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                REPEAT
                    countDescription := 0;
                    IF xItem.GET(xPosTrLines.Number) THEN BEGIN
                        DSTR1 := '#L######################################';
                        Value[1] := '*** ' + COPYSTR(xItem."LSC Attrib 1 Code", 1, 30) + ' ***';
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        IF xItem."FSN Showcase No." <> '' THEN BEGIN
                            DSTR1 := '#L######################################';
                            Value[1] := 'No. Estante:' + xItem."FSN Showcase No.";
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                        DSTR1 := '#L# #L##################################';
                        Value[1] := FORMAT(xPosTrLines.Quantity);

                        IF (xPosTrLines."Barcode No." <> '') THEN BEGIN
                            IF rBarras.GET(xPosTrLines."Barcode No.") THEN BEGIN
                                Value[2] := COPYSTR(rBarras.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                            END ELSE BEGIN
                                Value[2] := COPYSTR(xItem.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END
                        ELSE BEGIN
                            Value[2] := COPYSTR(xItem.Description, 1, 35);
                            countDescription := StrLen(xItem.Description);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                        if countDescription > 35 then begin
                            DSTR1 := '#L# #L##################################';
                            Value[1] := ' ';
                            Value[2] := COPYSTR(xItem.Description, 36, countDescription);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        end;

                        DSTR1 := 'PLU:1234567 1234567890123456789012345678';
                        DSTR1 := '#L######### #L##########################';
                        Value[1] := 'PLU:' + xPosTrLines.Number;
                        Value[2] := xPosTrLines."Unit of Measure";
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL xPosTrLines.NEXT = 0;
            END;

            DSTR1 := '#L######################################';
            CLEAR(xPosTrLines);
            xPosTrLines.RESET;
            xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::Item);
            xPosTrLines.SetFilter(xPosTrLines."FSN Additional Action", '<>%1', xPosTrLines."FSN Additional Action"::ConfirmRobot);
            xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
            IF xPosTrLines.FIND('-') THEN BEGIN
                DSTR1 := '#C######################################';
                Value[1] := '------------ PROCESO MANUAL -------------';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                REPEAT
                    countDescription := 0;
                    IF xItem.GET(xPosTrLines.Number) THEN BEGIN
                        DSTR1 := '#L######################################';
                        Value[1] := '*** ' + COPYSTR(xItem."LSC Attrib 1 Code", 1, 30) + ' ***';
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                        IF xItem."FSN Showcase No." <> '' THEN BEGIN
                            DSTR1 := '#L######################################';
                            Value[1] := 'No. Estante:' + xItem."FSN Showcase No.";
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                        DSTR1 := '#L# #L##################################';
                        Value[1] := FORMAT(xPosTrLines.Quantity);

                        IF (xPosTrLines."Barcode No." <> '') THEN BEGIN
                            IF rBarras.GET(xPosTrLines."Barcode No.") THEN BEGIN
                                Value[2] := COPYSTR(rBarras.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                            END ELSE BEGIN
                                Value[2] := COPYSTR(xItem.Description, 1, 35);
                                countDescription := StrLen(xItem.Description);
                                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                            END;
                        END
                        ELSE BEGIN
                            Value[2] := COPYSTR(xItem.Description, 1, 35);
                            countDescription := StrLen(xItem.Description);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        END;

                        if countDescription > 35 then begin
                            DSTR1 := '#L# #L##################################';
                            Value[1] := ' ';
                            Value[2] := COPYSTR(xItem.Description, 36, countDescription);
                            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        end;

                        DSTR1 := 'PLU:1234567 1234567890123456789012345678';
                        DSTR1 := '#L######### #L##########################';
                        Value[1] := 'PLU:' + xPosTrLines.Number;
                        Value[2] := xPosTrLines."Unit of Measure";
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL xPosTrLines.NEXT = 0;
            END;

            PrintUtil.PrintSeperator(Tray);

            CLEAR(xPosTrLines);
            xPosTrLines.SETRANGE("Receipt No.", POSTrans."Receipt No.");
            xPosTrLines.SETRANGE("Entry Type", xPosTrLines."Entry Type"::FreeText);
            //xPosTrLines.SETFILTER(xPosTrLines.Description, '<>%1', 'Prepagado');
            xPosTrLines.SETFILTER("Entry Status", '<>%1', xPosTrLines."Entry Status"::Voided);
            IF xPosTrLines.FIND('-') THEN
                REPEAT
                    DSTR1 := '#L######################################';
                    Value[1] := COPYSTR(xPosTrLines.Description, 1, 40);
                    PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

                    IF STRLEN(xPosTrLines.Description) > 40 THEN BEGIN
                        Value[1] := '   ' + COPYSTR(xPosTrLines.Description, 41, 37);
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;

                    IF STRLEN(xPosTrLines.Description) > 77 THEN BEGIN
                        Value[1] := '   ' + COPYSTR(xPosTrLines.Description, 78);
                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                    END;
                UNTIL xPosTrLines.NEXT = 0;

            xInfoCodeEntry.RESET;
            xInfoCodeEntry.SETRANGE(xInfoCodeEntry."Receipt No.", POSTrans."Receipt No.");
            xInfoCodeEntry.SETRANGE(xInfoCodeEntry."Transaction Type", 0);
            xInfoCodeEntry.SETFILTER(xInfoCodeEntry."Line No.", '26|27|31');
            IF xInfoCodeEntry.FINDSET THEN BEGIN
                DSTR1 := '#C######################################';
                Value[1] := '------- MENSAJE PARA MOTO -------';
                PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                DSTR1 := '#L######################################';
                REPEAT
                    xStrFrom := 1;
                    xFreeText := xInfoCodeEntry.Information;
                    xToInt := (STRLEN(xFreeText) DIV 38) + 1;
                    FOR xInt := 1 TO xToInt DO BEGIN
                        xNewText := COPYSTR(xFreeText, 1, 38);

                        Value[1] := xNewText;
                        IF xInt > 1 THEN
                            Value[1] := '  ' + xNewText;

                        PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
                        xFreeText := COPYSTR(xFreeText, 39);
                    END;
                UNTIL xInfoCodeEntry.NEXT = 0;
            END;

            PrintUtil.PrintSeperator(Tray);

            DSTR1 := '#L######################################';
            Value[1] := 'Fecha: ' + FORMAT(WORKDATE, 10, '<Day,2>/<Month,2>/<Year4>') + ' ' + FORMAT(TIME, 14, '<Hours12>:<Minutes,2>:<Seconds,2> <AM/PM>');
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            Value[1] := '';
            Value[2] := '';
            PrintUtil.PrintLine(Tray, PrintUtil.FormatLine(PrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            PrintUtil.ClosePrinter(2);

            TCommand := 'PRINTCARDVOUCHER';
            TransactorText := POSTrans."Receipt No.";
            FSNUtil.OninvokeGlobalChannelEvent(TransactorText, Tresponse, TCommand, POSMenuLineTemp, Processed, Response_Text);
            exit(true);
        end;
    end;

    procedure Post(Uri: Text; request: HttpRequestMessage; var CodeResult: Integer; var ErrorMessage: Text): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
        ErrorText: Label 'Los datos no representan un token válido de JSON.: %1';
    begin
        CodeResult := 0;
        request.Method := 'POST';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;
        //if status = 200 then begin
        content.ReadAs(res);
        if not jResponse.ReadFrom(res) then
            ErrorMessage := StrSubstNo(ErrorText, res);

        CodeResult := status;
        exit(jResponse);
        //end;
    end;

    //Guarda Json Robot
    procedure Save(DocumentNo: Code[20]; pText: Text; RType: Boolean)
    var
        directory: DotNet Directory;
        localpath: Label 'C:\temp\ROBOT\';
        fileName: Text;
        streamWriter: DotNet StreamWriter;
        currentDate: Text;

    begin

        if FSNParameter.get('ROBOT', 'PROCESS') and FSNParameter."Save Xml" then begin
            if not directory.Exists(localpath) then
                directory.CreateDirectory(localpath);

            currentDate := Format(Today(), 0, '<Closing><Day,2>-<Month,2>-<Year>');

            if RType then
                fileName := Format(localpath + StrSubstNo('/%1_Request.txt', DocumentNo))
            else
                fileName := Format(localpath + StrSubstNo('/%1_Response.txt', DocumentNo));
            streamWriter := streamWriter.StreamWriter(fileName);
            streamWriter.Write(pText);
            streamWriter.Close();
        end;
    end;

    //Pendiente de scaneo robot
    procedure ValidateItemPendingScann(POSTransaction: Record "LSC POS Transaction"; ItemNo: Code[20]; UnitofMeasureCoe: Code[10]; TenderTypeCode: Code[10]; SalesStaffID: Code[20]; var ErrorText: Text[250]; var ExitOnly: Boolean): Boolean
    var
        POSTransLine_l: Record "LSC POS Trans. Line";
        lText001: Label 'Cant add item %1 ';
        Item_l, Item_ : Record Item;
        Barcodes_l: Record "LSC Barcodes";
        ItemNo2: Code[20];
        Description: Text[50];
        lText002: Label 'No se encontraron lineas pendientes';
        CountUnit: Integer;
        ItemUnitofMeasure: Record "Item Unit of Measure";
        PosFunc: codeunit "LSC POS Functions";
        ErrorT: Text;
        caption: Label 'No Lote:';
        Result: Action;
        Datime: DateTime;
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        MsgResult: Text;
        Processedv: Boolean;
        POSGUI: Codeunit "LSC POS GUI";
    begin
        IF ItemNo = '' THEN
            EXIT(TRUE);

        IF NOT LinePendingConfirmScannExists(POSTransaction."Receipt No.") THEN BEGIN
            ExitOnly := true;
            EXIT(false);
        end else begin
            ExitOnly := FALSE;
        end;

        ItemNo2 := ItemNo;
        IF NOT Item_l.GET(ItemNo) THEN BEGIN
            IF Barcodes_l.GET(ItemNo) THEN BEGIN
                ItemNo := Barcodes_l."Item No.";
                Description := Barcodes_l.Description;
            END;
        END ELSE
            Description := Item_l.Description;

        POSTransLine_l.RESET;
        POSTransLine_l.SETCURRENTKEY("Receipt No.", "Entry Type", Number, "Variant Code", "Unit of Measure", "Entry Status");
        POSTransLine_l.SETRANGE(POSTransLine_l."Receipt No.", POSTransaction."Receipt No.");
        POSTransLine_l.SETRANGE(POSTransLine_l."Entry Type", POSTransLine_l."Entry Type"::Item);
        POSTransLine_l.SETRANGE(POSTransLine_l.Number, ItemNo);
        POSTransLine_l.SETFILTER(POSTransLine_l."Entry Status", '<>%1', POSTransLine_l."Entry Status"::Voided);
        POSTransLine_l.SETFILTER(POSTransLine_l."FSN Additional Action", '%1|%2', POSTransLine_l."FSN Additional Action"::ConfirmSala, POSTransLine_l."FSN Additional Action"::ConfirmRobot);
        IF POSTransLine_l.FindFirst THEN begin
            if Item_.Get(POSTransLine_l.Number) then
                if (POSTransLine_l."Lot No." IN ['', '#LOTCOMODIN']) AND (Item_."Item Tracking Code" <> '') then begin
                    POSSession.SetValue('#NOLOTE', Item_."No.");//28981 -1
                    POSGUI.OpenAlphabeticKeyboard(CopyStr(StrSubstNo(caption, Item_.Description), 1, 50), '', Result, true);
                end;
            IF POSTransLine_l."FSN QuantityScan" <> POSTransLine_l.Quantity THEN BEGIN
                IF Item_l.GET(POSTransLine_l.Number) THEN
                    ItemUnitofMeasure.RESET;
                ItemUnitofMeasure.SETRANGE(ItemUnitofMeasure."Item No.", POSTransLine_l.Number);
                IF ItemUnitofMeasure.FIND('-') THEN
                    REPEAT
                        CountUnit += 1;
                    UNTIL (ItemUnitofMeasure.NEXT = 0);

                IF CountUnit > 1 THEN
                    POSTransLine_l."FSN QuantityScan" := POSTransLine_l.Quantity
                ELSE
                    POSTransLine_l."FSN QuantityScan" := POSTransLine_l."FSN QuantityScan" + 1;
                POSTransLine_l.MODIFY;

                IF POSTransLine_l."FSN QuantityScan" = POSTransLine_l.Quantity THEN BEGIN
                    POSTransLine_l."FSN Additional Action" := POSTransLine_l."FSN Additional Action"::Nothing;
                    POSTransLine_l.MODIFY;
                END;

                ExitOnly := TRUE;
                ItemNo := '';
                EXIT(FALSE);

            END ELSE BEGIN
                POSTransLine_l."FSN Additional Action" := POSTransLine_l."FSN Additional Action"::Nothing;
                POSTransLine_l.MODIFY;
                ExitOnly := TRUE;
                ItemNo := '';
                EXIT(FALSE);
            END;
        END ELSE BEGIN
            IF Description = '' THEN BEGIN
                ErrorText := COPYSTR(STRSUBSTNO(lText001, ItemNo2), 1, 250);
            END ELSE
                ErrorText := COPYSTR(STRSUBSTNO(lText001, Description), 1, 250);
            EXIT(FALSE);
        END;
        POSSession.SetValue('FirstPass', 'false');
        EXIT(TRUE);
    end;

    //valida si hay que confirmar y bloquea si es delivery
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction", 'OnItemNoPressed', '', true, true)]
    local procedure "LSC POS Transaction_OnItemNoPressed"
    (
        REC: Record "LSC POS Transaction";
        CurrInput: Text;
        var Handled: Boolean
    )
    var
        ValidateItem: Boolean;
        pErrorText: text;
        pExitOnly: boolean;
        PosView: Codeunit "LSC POS View";
        CurrItem: Text;
        POSTransC: Codeunit "LSC POS Transaction";
        ErrorText: Text;
        _ExitOnly: Boolean;
    begin

        if LinePendingConfirmScannExists(REC."Receipt No.") then begin
            ValidateItemPendingScann(REC, COPYSTR(CurrInput, 1, 20), '', '', REC."Sales Staff", ErrorText, _ExitOnly);
            Handled := true;
            POSTransC.SetCurrInput(CurrItem);
            exit;
        END;
    END;

    //se valida si hay lineas pendiente de scanear
    procedure LinePendingConfirmScannExists(ReceiptNo: Code[20]): Boolean
    var
        POSTransLine2: Record "LSC POS Trans. Line";
    begin
        POSTransLine2.RESET;
        POSTransLine2.SETCURRENTKEY("Receipt No.", "Line No.");
        POSTransLine2.SETRANGE(POSTransLine2."Receipt No.", ReceiptNo);
        POSTransLine2.SETRANGE(POSTransLine2."Entry Type", POSTransLine2."Entry Type"::Item);
        POSTransLine2.SETRANGE(POSTransLine2."Entry Status", 0);
        POSTransLine2.SetFilter(POSTransLine2."FSN Additional Action", '%1|%2',
        POSTransLine2."FSN Additional Action"::ConfirmSala, POSTransLine2."FSN Additional Action"::ConfirmRobot);
        IF POSTransLine2.FINDFIRST then
            exit(true)
        else
            exit(false);
    end;

    //se valida que el pedido seleccionado no haya sido asignado a otra terminal al darle doble click
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
    (
    var PosEvent: Codeunit "LSC POS Event";
    var SuppressEvent: Boolean
    )
    var
        EPosCtrl: Codeunit "LSC POS Control Interface";
        OrderNo: Code[20];
        PosTrans: Record "LSC POS Transaction";
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
        ErrorMessage: Label 'Pedido ya Fue asignado a %1';
        TEXT003: Label 'El N° pedido %1 esta siendo facturado en el N° %2';
        DelOrder: Record "LSC Delivery Order";
        InUseOnPos: code[10];
        ParameterC: Record "FSN Parameter";
        prv: Record "FSN Parameter";
        Terminal: Record "LSC POS Terminal";
    begin
        IF prv.GET('ROBOT', 'PRINT') THEN
            IF prv.Activo THEN begin
                if (PosEvent.ActivePanel = '#OFFLINE') then
                    if Terminal.get(POSSESSION.TerminalNo()) then
                        if (Terminal."Interface Profile" = '#FSNMASTER') then
                            OnProcessPrintEvent();
            end;

        if PosEvent.ActivePanel = '#OFFLINE' THEN BEGIN
            if PosEvent.EventType in [
                    Enum::"LSC POS Event Type"::DATAROWDOUBLECLICK] then begin
                if FSNParameter.get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin
                    if FSNParameter.Get('ROBOT', 'PROCESSCALL') AND FSNParameter.Activo then begin
                        OrderNo := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                        if DelOrder.get(OrderNo) and (DelOrder."Order Type Option" <> 4) then begin
                            IF PosTrans.Get(OrderNo) then begin

                                if NOT ParameterC.get('ROBOT', 'VALIDAR') then
                                    if not GetUsePost(InUseOnPos, PosTrans) then begin
                                        Message(StrSubstNo(TEXT003, OrderNo, PosTrans."POS Terminal No."));
                                        exit;
                                    end;

                                if NOT prv.get('ROBOT', 'PRINTVAL') then BEGIN
                                    if PosTrans.Get(OrderNo) and (PosTrans."FSN Assigned PosTerminalNo" = '') or (PosTrans."FSN Status Robot" <> PosTrans."FSN Status Robot"::Procesado) then begin

                                        if PosTrans."FSN Assigned PosTerminalNo" <> '' then
                                            if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                                //se actualiza el panel
                                                POSMenulineTemp.Init();
                                                POSMenulineTemp."Profile ID" := 'FASANI';
                                                POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                                POSMenulineTemp.Description := 'Reiniciar';
                                                HospiPOSStartup.run(POSMenulineTemp);

                                                //se muestra mensaje si el pedido ya fue procesado
                                                Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                            end;

                                        POSSESSION.SetValue('ROBOTORDEREDIT', 'TRUE');
                                        Process(PosTrans, '');
                                        POSSESSION.SetValue('ROBOTORDEREDIT', '');
                                    end else begin
                                        if OrderNo <> '' then begin
                                            if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                                //se actualiza el panel
                                                POSMenulineTemp.Init();
                                                POSMenulineTemp."Profile ID" := 'FASANI';
                                                POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                                POSMenulineTemp.Description := 'Reiniciar';
                                                HospiPOSStartup.run(POSMenulineTemp);

                                                //se muestra mensaje si el pedido ya fue procesado
                                                Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                            end;
                                        end;
                                    end;
                                END ELSE BEGIN

                                    if PosTrans.Get(OrderNo) and (PosTrans."FSN Assigned PosTerminalNo" = '') then begin

                                        POSSESSION.SetValue('ROBOTORDEREDIT', 'TRUE');
                                        Process(PosTrans, '');
                                        POSSESSION.SetValue('ROBOTORDEREDIT', '');
                                    end else begin
                                        if OrderNo <> '' then begin
                                            if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                                                //se actualiza el panel
                                                POSMenulineTemp.Init();
                                                POSMenulineTemp."Profile ID" := 'FASANI';
                                                POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                                                POSMenulineTemp.Description := 'Reiniciar';
                                                HospiPOSStartup.run(POSMenulineTemp);

                                                //se muestra mensaje si el pedido ya fue procesado
                                                Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                                            end;
                                        end;
                                    end;
                                end;
                            end;
                        END;
                    end else begin
                        if FSNParameter.Get('ROBOT', 'SALES') THEN
                            IF FSNParameter.Activo then begin
                                OrderNo := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                                if OrderNo <> '' then
                                    ProcessOrderSales(OrderNo);
                            end;
                    end;
                end else begin
                    if FSNParameter.Get('ROBOT', 'SALES') THEN
                        IF FSNParameter.Activo then begin
                            OrderNo := EPosCtrl.GetDataGridKeyValue(EPosCtrl.ActiveDataGrid);
                            if OrderNo <> '' then
                                ProcessOrderSales(OrderNo);
                        end;
                end;
            END;
        END;
    end;

    local procedure getSQLInfo(VAR POSMenuLineTemp: Record "LSC POS Menu Line" temporary; Var CodeResult: Integer): Boolean
    var
        con: Text;
        sqlConnection: DotNet SqlConnection;
        sqlCommand: DotNet SqlCommand;
        sqlDataReader: DotNet SqlDataReader;
        distrLocation: Record "LSC Distribution Location";
        ReailUser: Record "LSC Retail Setup";
        ResultMessage: Text;
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false;User ID=%3;Password=%4;';
        ExpDateTxt: text;
        DayInt: Integer;
        MonthInt: Integer;
        YearInt: Integer;
        i: Integer;

    begin
        CodeResult := 000;
        Clear(POSMenuLineTemp);
        POSMenuLineTemp.DeleteAll();
        ReailUser.Get();
        if distrLocation.Get(POSSESSION.StoreNo()) then;

        con := StrSubstNo(lTextConn,
            distrLocation."DB Server Name",
            distrLocation."Db. Path && Name",
            distrLocation."User ID",
            distrLocation.Password);

        sqlConnection := sqlConnection.SqlConnection(con);
        sqlConnection.Open();

        sqlCommand := sqlConnection.CreateCommand();
        sqlCommand.CommandText := '[dbo].[DelTripDetail]';
        sqlCommand.CommandType := 4; // Tipo StoredProcedure

        //sqlCommand.Parameters.AddWithValue('@EntryCode', EntryCode);

        // Ejecutar SP
        sqlDataReader := sqlCommand.ExecuteReader();
        while sqlDataReader.Read() do begin
            // Mapeo de columnas según SELECT del SP
            CodeResult := 200;
            i += 1;
            POSMenuLineTemp.Init();
            POSMenuLineTemp."Profile ID" := 'FASANI';
            POSMenuLineTemp."Menu ID" := 'SQL';
            POSMenuLineTemp."Key No." := i;
            POSMenuLineTemp."Current-POSID" := Format(sqlDataReader.GetValue(0));
            POSMenuLineTemp."Current-StaffID" := Format(sqlDataReader.GetValue(1));
            POSMenuLineTemp."Current-STATE" := Format(sqlDataReader.GetValue(2));
            POSMenuLineTemp."Current-Price" := sqlDataReader.GetDecimal(3);
            POSMenuLineTemp.Insert();
        END;
        // Cerrar conexiones
        sqlDataReader.Close();
        sqlConnection.Close();
    end;

    //actualiza terminal en transaccion y demas tablas relacionadas
    procedure UpdateTransactionTerminal(LastSlipNo: Code[20]; POSTerminal: Code[10]; WindowsSelected: Integer)
    var
        POSTransLine, ValInventoryPosTransLine, POSLine : Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSTransInfocodeEntryTemp: Record "LSC POS Trans. Infocode Entry" temporary;
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        POSCardRequestEntry, POSCardReq_1 : Record "FSN POS Card Request Entry";
        POSCardEntry_l, PosCardEntry2 : Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        POSTransaction: Record "LSC POS Transaction";
        OferPosCalculetion: Record "LSC Offer Pos Calculation";
        POSTranslineTem: Record "LSC POS Trans. Line" temporary;
    begin

        //POSTerminal := InsStr(POSTerminal, '#', 3);

        //POS Transaction.
        POSTransaction.Reset();
        if POSTransaction.Get(LastSlipNo) then begin
            POSTransaction."POS Terminal No." := POSTerminal;
            POSTransaction."FSN Assigned PosTerminalNo" := POSTerminal;
            POSTransaction."FSN Status Robot" := POSTransaction."FSN Status Robot"::Procesado;
            POSTransaction."Staff ID" := POSSESSION.StaffID();
            POSTransaction."FSN state of preparation" := POSTransaction."FSN state of preparation"::Preparando;
            if WindowsSelected <> 0 then
                POSTransaction."FSN Ventanilla" := WindowsSelected;
            POSTransaction.Modify(true);
        end;

        //POS Trans. Line.
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", LastSlipNo);
        if POSTransLine.Find('-') then begin
            repeat
                POSTransLine."POS Terminal No." := POSTerminal;
                POSTransLine.Modify();
            until POSTransLine.Next() = 0;
        end;

        Commit();

        //LSC POS Trans. Per. Disc. Type
        POSTPeriodicType.Reset();
        POSTPeriodicType.SetRange("Receipt No.", LastSlipNo);
        if POSTPeriodicType.Find('-') then begin
            repeat
                POSTPeriodicType."POS Terminal No." := POSTerminal;
                POSTPeriodicType.Modify(true);
            until POSTPeriodicType.Next() = 0;
        end;


        //LSC POS Trans. Infocode Entry
        POSTransInfocodeEntry.Reset();
        POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", LastSlipNo);
        if POSTransInfocodeEntry.Find('-') then begin
            repeat
                POSTransInfocodeEntryTemp := POSTransInfocodeEntry;
                POSTransInfocodeEntryTemp."POS Terminal No." := POSTerminal;
                POSTransInfocodeEntryTemp.Insert();
                POSTransInfocodeEntry.Delete();

                POSTransInfocodeEntry := POSTransInfocodeEntryTemp;
                POSTransInfocodeEntry.Insert();

            until POSTransInfocodeEntry.Next() = 0;
        end;

        //LSC Voucher Entries
        VoucherEntry.Reset();
        VoucherEntry.SetRange("Receipt Number", LastSlipNo);
        if VoucherEntry.Find('-') then begin
            repeat
                VoucherEntry."POS Terminal No." := POSTerminal;
                VoucherEntry.Modify();
            until VoucherEntry.Next() = 0;
        end;

        POSCardEntry_l.RESET;
        POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", LastSlipNo);
        IF POSCardEntry_l.FIND('-') THEN
            REPEAT
                POSCardEntryTmp := POSCardEntry_l;
                POSCardEntryTmp."POS Terminal No." := POSTerminal;
                IF NOT (POSCardEntryTmp.INSERT) THEN begin
                    POSCardEntryTmp.MODIFY;
                end else begin
                    PosCardEntry2 := POSCardEntryTmp;
                    PosCardEntry2.Insert();
                    POSCardEntry_l.Delete();
                    POSCardEntryTmp.Delete();
                end;
            UNTIL POSCardEntry_l.NEXT = 0;

        Commit();
    end;

    procedure UpdateTransactionTerminalAut(LastSlipNo: Code[20]; POSTerminal: Code[10])
    var
        POSTransLine, ValInventoryPosTransLine, POSLine : Record "LSC POS Trans. Line";
        POSTPeriodicType: Record "LSC POS Trans. Per. Disc. Type";
        POSTransInfocodeEntry: Record "LSC POS Trans. Infocode Entry";
        POSTransInfocodeEntryTemp: Record "LSC POS Trans. Infocode Entry" temporary;
        POSDataEntry: Record "LSC POS Data Entry";
        VoucherEntry: Record "LSC Voucher Entries";
        POSCardRequestEntry, POSCardReq_1 : Record "FSN POS Card Request Entry";
        POSCardEntry_l, PosCardEntry2 : Record "LSC POS Card Entry";
        POSCardEntryTmp: Record "LSC POS Card Entry" temporary;
        PosCardReqIn: Record "FSN POS Card Request Inherit";
        POSTransaction: Record "LSC POS Transaction";
        OferPosCalculetion: Record "LSC Offer Pos Calculation";
        POSTranslineTem: Record "LSC POS Trans. Line" temporary;
    begin

        //POSTerminal := InsStr(POSTerminal, '#', 3);

        //POS Transaction.
        POSTransaction.Reset();
        if POSTransaction.Get(LastSlipNo) then begin
            POSTransaction."POS Terminal No." := POSTerminal;
            POSTransaction."FSN Assigned PosTerminalNo" := POSTerminal;
            POSTransaction."FSN Status Robot" := POSTransaction."FSN Status Robot"::Procesado;
            POSTransaction."Staff ID" := POSSESSION.StaffID();
            POSTransaction."FSN state of preparation" := POSTransaction."FSN state of preparation"::Preparando;
            POSTransaction.Modify(true);
        end;

        //POS Trans. Line.
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", LastSlipNo);
        if POSTransLine.Find('-') then begin
            repeat
                POSTransLine."POS Terminal No." := POSTerminal;
                POSTransLine.Modify();
            until POSTransLine.Next() = 0;
        end;

        Commit();

        //LSC POS Trans. Per. Disc. Type
        POSTPeriodicType.Reset();
        POSTPeriodicType.SetRange("Receipt No.", LastSlipNo);
        if POSTPeriodicType.Find('-') then begin
            repeat
                POSTPeriodicType."POS Terminal No." := POSTerminal;
                POSTPeriodicType.Modify(true);
            until POSTPeriodicType.Next() = 0;
        end;


        //LSC POS Trans. Infocode Entry
        POSTransInfocodeEntry.Reset();
        POSTransInfocodeEntry.SetRange(POSTransInfocodeEntry."Receipt No.", LastSlipNo);
        if POSTransInfocodeEntry.Find('-') then begin
            repeat
                POSTransInfocodeEntryTemp := POSTransInfocodeEntry;
                POSTransInfocodeEntryTemp."POS Terminal No." := POSTerminal;
                POSTransInfocodeEntryTemp.Insert();
                POSTransInfocodeEntry.Delete();

                POSTransInfocodeEntry := POSTransInfocodeEntryTemp;
                POSTransInfocodeEntry.Insert();

            until POSTransInfocodeEntry.Next() = 0;
        end;

        //LSC Voucher Entries
        VoucherEntry.Reset();
        VoucherEntry.SetRange("Receipt Number", LastSlipNo);
        if VoucherEntry.Find('-') then begin
            repeat
                VoucherEntry."POS Terminal No." := POSTerminal;
                VoucherEntry.Modify();
            until VoucherEntry.Next() = 0;
        end;

        POSCardEntry_l.RESET;
        POSCardEntry_l.SETRANGE(POSCardEntry_l."Receipt No.", LastSlipNo);
        IF POSCardEntry_l.FIND('-') THEN
            REPEAT
                POSCardEntryTmp := POSCardEntry_l;
                POSCardEntryTmp."POS Terminal No." := POSTerminal;
                IF NOT (POSCardEntryTmp.INSERT) THEN begin
                    POSCardEntryTmp.MODIFY;
                end else begin
                    PosCardEntry2 := POSCardEntryTmp;
                    PosCardEntry2.Insert();
                    POSCardEntry_l.Delete();
                    POSCardEntryTmp.Delete();
                end;
            UNTIL POSCardEntry_l.NEXT = 0;

        Commit();
    end;

    procedure ValidateLotVence(ReceiptNo: Code[20])
    var
        POSTransLine: Record "LSC POS Trans. Line";
        Item: Record Item;
    begin
        POSTransLine.Reset();
        POSTransLine.SETRANGE("Receipt No.", ReceiptNo);
        POSTransLine.SETRANGE("Entry Type", POSTransLine."Entry Type"::Item);
        if POSTransLine.Find('-') then begin
            repeat
                if Item.Get(POSTransLine.Number) THEN
                    if Item."Item Tracking Code" <> '' then begin
                        POSTransLine."Lot No." := '#LOTCOMODIN';
                        POSTransLine.MODIFY;
                    end;
            until POSTransLine.Next() = 0;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnIdleTimerTickEvent', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnIdleTimerTickEvent"
        (
            ActiveDiningArea: Record "LSC Dining Area";
            var HospitalityTypeTemp: Record "LSC Hospitality Type";
            ActiveServiceFlow: Record "LSC Hospitality Service Flow"
        )
    var
        pr: Record "FSN Parameter";
    begin

        IF pr.GET('ROBOT', 'PRINT') THEN
            IF pr.Activo THEN
                exit;

        OnProcessPrintEvent();//Se separo el funcionamientos a un proceso aparte

    end;

    procedure OnProcessPrintEvent()
    var
        DelOrderTbl, DelOrdM : Record "LSC Delivery Order";
        POSTransactionTbl: Record "LSC POS Transaction";
        FSNParameterRT: Record "FSN Parameter";
        TerminalNo: code[10];
        Win: Integer;
        pr: Record "FSN Parameter";
    begin
        DelOrderTbl.RESET;
        DelOrderTbl.SETRANGE("Printed OK", FALSE);//20260424
        IF DelOrderTbl.FIND('-') THEN
            REPEAT
                IF POSTransactionTbl.GET(DelOrderTbl."Order No.") THEN begin
                    if FSNParameterRT.Get('ROBOT', 'PROCESSCALL') AND FSNParameterRT.Activo then begin
                        if FSNParameterRT.Get('ROBOT', 'PROCESS') and (DelOrderTbl."Order Type Option" <> 4) then begin
                            if (POSSESSION.TerminalNo() = FSNParameterRT."Value Text 1") then begin
                                //se actualiza la terminal
                                Clear(TerminalNo);
                                Win := 0;
                                if not ValidateTIp(POSTransactionTbl."Receipt No.") then begin
                                    if pr.Get('ROBOT', 'TIMER') THEN BEGIN
                                        if ValTerminalDAF(POSTransactionTbl, TerminalNo) then begin

                                            if POSTransactionTbl."POS Terminal No." <> TerminalNo then
                                                UpdateTransactionTerminal(POSTransactionTbl."Receipt No.", TerminalNo, Win);

                                            if POSTransactionTbl.Get(POSTransactionTbl."Receipt No.") then
                                                Process(POSTransactionTbl, TerminalNo);

                                            if DelOrdM.Get(DelOrderTbl."Order No.") then
                                                if not DelOrdM."Printed OK" then begin
                                                    DelOrdM."Printed OK" := TRUE;
                                                    DelOrdM.MODIFY();
                                                end;
                                        end;
                                    END;
                                end else begin
                                    PrintSlipRobot(POSTransactionTbl."Receipt No.");
                                    if DelOrdM.Get(DelOrderTbl."Order No.") then
                                        if not DelOrdM."Printed OK" then begin
                                            DelOrdM."Printed OK" := TRUE;
                                            DelOrdM.MODIFY();
                                        end;
                                end;
                            end;
                        end;
                    end;
                end;
            UNTIL DelOrderTbl.NEXT = 0;
    end;

    procedure ValidateTIp(OrderNo: Code[20]): Boolean;
    var
        myInt: Integer;
        TransLine: Record "LSC POS Trans. Line";
    begin
        TransLine.Reset();
        TransLine.SetRange("Receipt No.", OrderNo);
        TransLine.SetRange(TransLine."Entry Type", TransLine."Entry Type"::Item);
        TransLine.SetRange(TransLine.Number, '70107');
        if TransLine.FindFirst() then
            exit(true)
        else
            exit(false);
    end;

    procedure ValTerminalDAF(POSTransac: Record "LSC POS Transaction"; var TerminalNo: Code[10]): Boolean
    var
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin
        InfoEntry.Reset();
        InfoEntry.SetRange("Receipt No.", POSTransac."Receipt No.");
        InfoEntry.SetRange("Transaction Type", 0);
        InfoEntry.SetRange("Line No.", 70);
        InfoEntry.SetRange(Infocode, 'TEXT');
        IF InfoEntry.FINDFIRST then begin
            TerminalNo := InfoEntry.Information;
            exit(true)
        end else
            exit(false);
    end;

    local procedure GetInfocode(xPOStemp: Record "LSC POS Transaction"; var WindowsSelect: Integer)
    var
        InfoEntry: Record "LSC POS Trans. Infocode Entry";
    begin
        InfoEntry.Reset();
        InfoEntry.SetRange("Receipt No.", xPOStemp."Receipt No.");
        InfoEntry.SetRange("Transaction Type", 0);
        InfoEntry.SetRange("Line No.", 60);
        if InfoEntry.FindFirst() then
            if Evaluate(WindowsSelect, format(InfoEntry.Information)) then;

    end;

    procedure GetUsePost(var InUseOnPos: Code[10]; SelectedPOSTrans: Record "LSC POS Transaction"): Boolean
    var
        PosFunctions: Codeunit "LSC POS Functions";

    begin
        InUseOnPos := PosFunctions.GetTransInUseOnPos(SelectedPOSTrans."Receipt No.");

        if (InUseOnPos <> '') then begin
            if InUseOnPos <> POSSESSION.TerminalNo() then
                exit(false)
            else
                exit(true);
        end else
            exit(true);
    end;

    ////////////////////////////FAC VENTA///////////////////////////////
    procedure ProcessFacSales(IdTransaction: Integer)
    var
        SalesHeader: Record "Sales Header";
        SalesSetup: Record "Sales & Receivables Setup";
        NoSeriesMgt: Codeunit NoSeriesManagement;
        FSNParameter: Record "FSN Parameter";
        FSNVendingHeader: Record "FSN Vending Header";
        Customer: Record Customer;
        PaymentMethod: Record "Payment Method";
        FSNUtility: Codeunit "FSN Utility";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        ErrorMessage: text;
        TransactionSpecification: Record "Transaction Specification";
        TEXT000: label 'No se a especificado codigo almancen para Machine %1 en FSN Parametros';
    begin
        FSNVendingHeader.Reset();
        if IdTransaction <> 0 then
            FSNVendingHeader.SetRange(FSNVendingHeader.idTransaction, IdTransaction)
        else
            FSNVendingHeader.SetRange(FSNVendingHeader.Process, false);
        if FSNVendingHeader.Find('-') then begin
            repeat
                FSNParameter.Reset();
                FSNParameter.SetRange(FSNParameter.Grupo, 'ROBOT');
                FSNParameter.SetRange(FSNParameter.Codigo, 'MACHINE');
                FSNParameter.SetRange(FSNParameter.Valor, Format(FSNVendingHeader.idMachine));
                if FSNParameter.FindFirst() then
                    if FSNParameter.Activo then begin
                        if FSNVendingHeader."FC No" = '' then begin


                            if FSNParameter."Distribution Location Ext." = '' then
                                error(StrSubstNo(TEXT000, FSNVendingHeader.idMachine));

                            SalesSetup.Get();
                            SalesHeader.Reset();
                            SalesHeader.Init();
                            SalesHeader."No." := '';
                            SalesHeader."Document Type" := FSNVendingHeader."Document Type";
                            NoSeriesMgt.InitSeries(SalesSetup."Invoice Nos.", SalesHeader."No. Series", SalesHeader."Posting Date", SalesHeader."No.", SalesHeader."No. Series");

                            if TransactionSpecification.get('VENDING') then
                                SalesHeader."Transaction Specification" := TransactionSpecification.Code
                            else
                                SalesHeader."Transaction Specification" := '';

                            FSNVendingHeader."FC No" := SalesHeader."No.";
                            FSNVendingHeader.Modify();

                            IF FSNVendingHeader.DUI = '' THEN begin
                                SalesHeader.Validate("Sell-to Customer No.", FSNParameter."Value Text 1");///Cliente general por defecto
                                SalesHeader.Validate("Bill-to Customer No.", FSNParameter."Value Text 1");
                            end ELSE BEGIN
                                Customer.Reset();
                                Customer.SetRange(Customer."FSN DUI", FSNVendingHeader.DUI);
                                IF Customer.FIND('-') THEN begin
                                    SalesHeader.Validate("Sell-to Customer No.", Customer."No.");//si encuentra cliente por DUI lo asigna, sino cliente general
                                    SalesHeader.Validate("Bill-to Customer No.", Customer."No.");
                                end ELSE begin
                                    SalesHeader.Validate("Sell-to Customer No.", FSNParameter."Value Text 1");//Cliene general por defecto
                                    SalesHeader.Validate("Bill-to Customer No.", FSNParameter."Value Text 1");
                                end;

                            END;

                            if PaymentMethod.Get(FSNParameter."Value Text 2") then//metodo de pago por defecto
                                SalesHeader."Payment Method Code" := PaymentMethod.Code;

                            SalesHeader.Insert(true);

                            IF SalesHeader.GET(SalesHeader."Document Type", SalesHeader."No.") THEN BEGIN
                                SalesHeader."Location Code" := FSNParameter."Distribution Location Ext.";
                                SalesHeader."Order Date" := DT2DATE(FSNVendingHeader.DateHours);
                                SalesHeader."Posting Date" := DT2DATE(FSNVendingHeader.DateHours);
                                SalesHeader."Document Date" := DT2DATE(FSNVendingHeader.DateHours);
                                SalesHeader.Modify(true);
                            END;

                            ProcessFacSalesLine(FSNVendingHeader, SalesHeader);

                            RequestID := 'VENDING';
                            XMLRequest := SalesHeader."No.";

                            POSMenuLineTemp.Reset();
                            POSMenuLineTemp.DeleteAll();
                            Clear(POSMenuLineTemp);
                            POSMenuLineTemp.Init();
                            POSMenuLineTemp."Profile ID" := 'FASANI';
                            POSMenuLineTemp."Menu ID" := 'VENDING';
                            POSMenuLineTemp."Key No." := 1;
                            POSMenuLineTemp."Set Current-Input" := FSNVendingHeader."DTE Invoice";
                            POSMenuLineTemp."Current-Description" := FSNVendingHeader."DTE AuthNumber";
                            POSMenuLineTemp."Current-Description2" := FSNVendingHeader."Signature Validation";
                            POSMenuLineTemp.Insert();

                            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, ErrorMessage);

                            /*if FSNParameter."Save Xml" then
                                SalesPostYesNo.Run(SalesHeader);*/

                            if FSNParameter."Save Xml" then
                                SalesPostYesNo(SalesHeader, FSNVendingHeader);

                        end else begin
                            SalesHeader.reset;
                            SalesHeader.setrange(SalesHeader."Document Type", FSNVendingHeader."Document Type"::Invoice);
                            SalesHeader.setrange(SalesHeader."No.", FSNVendingHeader."FC No");
                            if SalesHeader.FindFirst() then begin
                                if FSNParameter."Save Xml" then
                                    SalesPostYesNo(SalesHeader, FSNVendingHeader);
                            end;
                        end;
                    end;
            until FSNVendingHeader.Next() = 0;
        end;
    end;

    procedure SalesPostYesNo(SalesHeader: Record "Sales Header"; FSNVendingHeader: Record "FSN Vending Header")
    var
    begin
        Commit();
        IF NOT CODEUNIT.RUN(CODEUNIT::"Sales-Post (Yes/No)", SalesHeader) THEN BEGIN
            FSNVendingHeader."FC Message Error" := COPYSTR(GETLASTERRORTEXT, 1, 249);
            FSNVendingHeader.Modify();
        END ELSE BEGIN
            FSNVendingHeader.Process := true;
            FSNVendingHeader.Modify();
        END;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Sales-Post (Yes/No)", 'OnBeforeConfirmSalesPost', '', true, true)]
    local procedure "Sales-Post (Yes/No)_OnBeforeConfirmSalesPost"
    (
        var SalesHeader: Record "Sales Header";
        var HideDialog: Boolean;
        var IsHandled: Boolean;
        var DefaultOption: Integer;
        var PostAndSend: Boolean
    )
    begin
        HideDialog := ValVending(SalesHeader);
    end;


    [EventSubscriber(ObjectType::Table, Database::"Sales Header", 'OnBeforeRecreateSalesLinesHandler', '', true, true)]
    local procedure "Sales Header_OnBeforeRecreateSalesLinesHandler"
    (
        var SalesHeader: Record "Sales Header";
        xSalesHeader: Record "Sales Header";
        ChangedFieldName: Text[100];
        var IsHandled: Boolean
    )
    begin
        IsHandled := ValVending(SalesHeader);
    end;

    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnDeleteRecordEvent"
    (
        var Rec: Record "Sales Header";
        var AllowDelete: Boolean
    )
    var
        TEXT000: LABEL 'No puede anular la Factura Venta(Vending)';
    begin
        IF ValVending(Rec) THEN begin
            AllowDelete := false;
            Message(TEXT000);
        end;
    end;

    //Bloquea informacion del DTE en la factura de venta
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', true, true)]
    local procedure "FSN Utility_OnInvokeGlobalChannelEvent"
    (
    var XMLRequest: Text;
    var XMLResponse: Text;
    var RequestID: Text[50];
    var POSMenuLine: Record "LSC POS Menu Line";
    var Processed: Boolean;
    var MsgResult: Text
    )
    var
        SalesHeader: Record "Sales Header";
    begin

        if RequestID = 'VENDINGVAL' then begin
            SalesHeader.Reset();
            SalesHeader.SetRange(SalesHeader."Document Type", SalesHeader."Document Type"::Invoice);
            SalesHeader.SetRange(SalesHeader."No.", XMLRequest);
            if SalesHeader.FindFirst() then begin
                Processed := ValVending(SalesHeader);
            end;

        end;
    END;


    /*[EventSubscriber(ObjectType::Page, Page::"Sales Invoice", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Sales Invoice_OnModifyRecordEvent"
    (
        var Rec: Record "Sales Header";
        var xRec: Record "Sales Header";
        var AllowModify: Boolean
    )
    var
        TEXT000: LABEL 'No puede Modificar la Factura Venta(Vending)';
    begin
        IF ValVending(Rec) THEN begin
            Message(TEXT000);
        end;
    end;*/


    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice Subform", 'OnModifyRecordEvent', '', true, true)]
    local procedure "Sales Invoice Subform_OnModifyRecordEvent"
    (
        var Rec: Record "Sales Line";
        var xRec: Record "Sales Line";
        var AllowModify: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        TEXT000: LABEL 'No puede MODIFICAR la Factura Venta(Vending)';
    begin
        SalesHeader.reset;
        SalesHeader.setrange(SalesHeader."Document Type", Rec."Document Type"::Invoice);
        SalesHeader.setrange(SalesHeader."No.", Rec."Document No.");
        if SalesHeader.FindFirst() then
            if ValVending(SalesHeader) then begin
                error(TEXT000);
            end;
    end;



    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice Subform", 'OnDeleteRecordEvent', '', true, true)]
    local procedure "Sales Invoice Subform_OnDeleteRecordEvent"
    (
        var Rec: Record "Sales Line";
        var AllowDelete: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        TEXT000: LABEL 'No puede ELIMINAR productos de la Factura Venta(Vending)';
    begin
        SalesHeader.reset;
        SalesHeader.setrange(SalesHeader."Document Type", Rec."Document Type"::Invoice);
        SalesHeader.setrange(SalesHeader."No.", Rec."Document No.");
        if SalesHeader.FindFirst() then
            if ValVending(SalesHeader) then begin
                error(TEXT000);
            end;
    end;


    [EventSubscriber(ObjectType::Page, Page::"Sales Invoice Subform", 'OnInsertRecordEvent', '', true, true)]
    local procedure "Sales Invoice Subform_OnInsertRecordEvent"
    (
        var Rec: Record "Sales Line";
        var xRec: Record "Sales Line";
        var AllowInsert: Boolean;
        BelowxRec: Boolean
    )
    var
        SalesHeader: Record "Sales Header";
        TEXT000: LABEL 'No puede INSERTAR productos en la Factura Venta(Vending)';
    begin
        SalesHeader.reset;
        SalesHeader.setrange(SalesHeader."Document Type", Rec."Document Type"::Invoice);
        SalesHeader.setrange(SalesHeader."No.", Rec."Document No.");
        if SalesHeader.FindFirst() then
            if ValVending(SalesHeader) then begin
                error(TEXT000);
            end;
    end;


    procedure ValVending(SalesHeader: Record "Sales Header"): Boolean
    var
        FSNVendingHeader: Record "FSN Vending Header";
        SalesInvoiceList: Page "Sales Invoice List";
    begin
        FSNVendingHeader.Reset();
        FSNVendingHeader.SetRange(FSNVendingHeader."FC No", SalesHeader."No.");
        if FSNVendingHeader.FindFirst() then
            exit(true)
        else
            exit(false);

    end;

    local procedure ProcessFacSalesLine(FSNVendingHeader: Record "FSN Vending Header"; SalesHeader: Record "Sales Header")
    var
        SalesLine: Record "Sales Line";
        FSNVendingLine: Record "FSN Vending Line";
        Item: Record Item;
        UnitMgn: Codeunit "Unit of Measure Management";
        VATPostingSetup: Record "VAT Posting Setup";
        ItemUnitofMeasure: Record "Item Unit of Measure";


    begin
        FSNVendingLine.Reset();
        FSNVendingLine.SetRange(FSNVendingLine."IdMachine", FSNVendingHeader."IdMachine");
        FSNVendingLine.SetRange(FSNVendingLine."IdTransaction", FSNVendingHeader."IdTransaction");
        if FSNVendingLine.Find('-') then begin
            repeat
                SalesLine.Init();
                SalesLine."Document Type" := SalesLine."Document Type"::Invoice;
                SalesLine."Sell-to Customer No." := SalesHeader."Sell-to Customer No.";
                SalesLine."Bill-to Customer No." := SalesHeader."Bill-to Customer No.";
                SalesLine."Location Code" := SalesHeader."Location Code";
                SalesLine."Currency Code" := SalesHeader."Currency Code";
                SalesLine."Customer Price Group" := SalesHeader."Customer Price Group";
                SalesLine."Customer Disc. Group" := SalesHeader."Customer Disc. Group";
                SalesLine."Allow Line Disc." := SalesHeader."Allow Line Disc.";
                SalesLine."Transaction Type" := SalesHeader."Transaction Type";
                SalesLine."Transport Method" := SalesHeader."Transport Method";
                SalesLine."Bill-to Customer No." := SalesHeader."Bill-to Customer No.";
                SalesLine."Price Calculation Method" := SalesHeader."Price Calculation Method";
                SalesLine."Gen. Bus. Posting Group" := SalesHeader."Gen. Bus. Posting Group";
                SalesLine."VAT Bus. Posting Group" := SalesHeader."VAT Bus. Posting Group";
                SalesLine."Exit Point" := SalesHeader."Exit Point";
                SalesLine.Area := SalesHeader.Area;
                SalesLine."Transaction Specification" := SalesHeader."Transaction Specification";
                SalesLine."Tax Area Code" := SalesHeader."Tax Area Code";
                SalesLine."Tax Liable" := SalesHeader."Tax Liable";
                SalesLine."Prepayment %" := SalesHeader."Prepayment %";
                SalesLine."Prepayment Tax Area Code" := SalesHeader."Tax Area Code";
                SalesLine."Prepayment Tax Liable" := SalesHeader."Tax Liable";
                SalesLine."Responsibility Center" := SalesHeader."Responsibility Center";
                SalesLine."Shipping Agent Code" := SalesHeader."Shipping Agent Code";
                SalesLine."Shipping Agent Service Code" := SalesHeader."Shipping Agent Service Code";
                SalesLine."Outbound Whse. Handling Time" := SalesHeader."Outbound Whse. Handling Time";
                SalesLine."Shipping Time" := SalesHeader."Shipping Time";
                SalesLine."Document No." := SalesHeader."No.";
                SalesLine."Line No." := FSNVendingLine.lineNo;
                SalesLine.Type := SalesLine.Type::Item;
                SalesLine."No." := FSNVendingLine.idProduct;
                if Item.Get(SalesLine."No.") then;
                SalesLine.Description := Item.Description;
                SalesLine."Description 2" := Item."Description 2";
                SalesLine."Allow Invoice Disc." := Item."Allow Invoice Disc.";
                SalesLine."Units per Parcel" := Item."Units per Parcel";
                SalesLine."Gen. Prod. Posting Group" := Item."Gen. Prod. Posting Group";
                SalesLine."VAT Prod. Posting Group" := Item."VAT Prod. Posting Group";
                SalesLine.Validate(SalesLine."VAT Prod. Posting Group");
                SalesLine."Tax Group Code" := Item."Tax Group Code";
                SalesLine."Package Tracking No." := SalesHeader."Package Tracking No.";
                SalesLine."Item Category Code" := Item."Item Category Code";
                SalesLine.Nonstock := Item."Created From Nonstock Item";
                SalesLine."Profit %" := Item."Profit %";
                SalesLine.Reserve := Item.Reserve;
                SalesLine."Allow Item Charge Assignment" := true;
                SalesLine."LSC Division" := Item."LSC Division Code";
                SalesLine."LSC Retail Product Code" := Item."LSC Retail Product Code";
                SalesLine."Posting Group" := Item."Inventory Posting Group";
                SalesLine."Unit of Measure Code" := Item."Purch. Unit of Measure";
                SalesLine.Validate(SalesLine."Unit of Measure Code");
                SalesLine."Qty. per Unit of Measure" := UnitMgn.GetQtyPerUnitOfMeasure(Item, SalesLine."Unit of Measure Code");
                SalesLine.Validate(SalesLine."Unit Cost (LCY)", Item."Unit Cost" * SalesLine."Qty. per Unit of Measure");
                if VATPostingSetup.Get(SalesLine."VAT Bus. Posting Group", SalesLine."VAT Prod. Posting Group") then;
                SalesLine."VAT %" := VATPostingSetup."VAT %";
                SalesLine."VAT Calculation Type" := VATPostingSetup."VAT Calculation Type";
                SalesLine."VAT Identifier" := VATPostingSetup."VAT Identifier";
                SalesLine."VAT Clause Code" := VATPostingSetup."VAT Clause Code";

                SalesLine.Validate(SalesLine.Quantity, FSNVendingLine.Quantity);
                SalesLine."Outstanding Quantity" := FSNVendingLine.Quantity;
                SalesLine."Qty. to Invoice" := FSNVendingLine.Quantity;
                SalesLine."Qty. to Invoice (Base)" := FSNVendingLine.Quantity;
                //SalesLine."Qty. Invoiced (Base)" := FSNVendingLine.Quantity;
                SalesLine."Qty. to Ship" := FSNVendingLine.Quantity;
                SalesLine."Qty. to Ship (Base)" := FSNVendingLine.Quantity;
                SalesLine."Quantity (Base)" := FSNVendingLine.Quantity;
                SalesLine."Line Amount" := FSNVendingLine.price / 1.13;
                SalesLine."Amount" := FSNVendingLine.price / 1.13;
                SalesLine."VAT Base Amount" := FSNVendingLine.price / 1.13;
                SalesLine."Amount Including VAT" := FSNVendingLine.price;
                SalesLine.Validate(SalesLine."Unit Price", FSNVendingLine.price / 1.13);
                SalesLine.Insert(true);
            until FSNVendingLine.Next() = 0;
        end;
    end;

    procedure InsertVendingLine(IdMachine: Integer; IdTransaction: Integer)
    var
        FSNVendingLine: Record "FSN Vending Line";
        SalesLine: Record "Sales Line";
    begin
        FSNVendingLine.SetCurrentKey("IdMachine", "IdTransaction", lineNo);
        FSNVendingLine.SetRange(FSNVendingLine."IdMachine", IdMachine);
        FSNVendingLine.SetRange(FSNVendingLine."IdTransaction", IdTransaction);
        if FSNVendingLine.Find('-') then begin
            repeat

            until FSNVendingLine.Next() = 0;
        end;
    end;

    ///////////////////////////////////////////////////////////////////////////////


    procedure ProcessOrderSales(OrderNo: Code[20])
    var
        DelOrder: Record "LSC Delivery Order";
        PosTrans: Record "LSC POS Transaction";
        InUseOnPos: code[10];
        TEXT003: Label 'El N° pedido %1 esta siendo facturado en el N° %2';
        POSMenulineTemp: Record "LSC POS Menu Line" temporary;
        ErrorMessage: Label 'Pedido ya Fue asignado al %1';
        HospiPOSStartup: codeunit "LSC Hospitality POS Startup";
    begin
        IF DelOrder.Get(OrderNo) and (DelOrder."Order Type Option" <> 4) THEN BEGIN
            if PosTrans.Get(OrderNo) then begin

                if not GetUsePost(InUseOnPos, PosTrans) then begin
                    Message(StrSubstNo(TEXT003, OrderNo, PosTrans."POS Terminal No."));
                    exit;
                end;

                if PosTrans.Get(OrderNo) and (PosTrans."FSN Assigned PosTerminalNo" = '') or (PosTrans."FSN Status Robot" <> PosTrans."FSN Status Robot"::Procesado) then begin

                    if PosTrans."FSN Assigned PosTerminalNo" <> '' then
                        if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin

                            //se actualiza el panel
                            POSMenulineTemp.Init();
                            POSMenulineTemp."Profile ID" := 'FASANI';
                            POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                            POSMenulineTemp.Description := 'Reiniciar';
                            HospiPOSStartup.run(POSMenulineTemp);

                            //se muestra mensaje si el pedido ya fue procesado
                            Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                        end;

                    POSSESSION.SetValue('ROBOTORDEREDIT', 'TRUE');
                    UpdateOrderSales(PosTrans."Receipt No.");
                    POSSESSION.SetValue('ROBOTORDEREDIT', '');
                end else begin
                    if OrderNo <> '' then begin
                        if PosTrans."FSN Assigned PosTerminalNo" <> POSSESSION.TerminalNo() then begin
                            //se actualiza el panel
                            POSMenulineTemp.Init();
                            POSMenulineTemp."Profile ID" := 'FASANI';
                            POSMenulineTemp.Command := 'HOSP-SEARCHRESET';
                            POSMenulineTemp.Description := 'Reiniciar';
                            HospiPOSStartup.run(POSMenulineTemp);

                            //se muestra mensaje si el pedido ya fue procesado
                            Error(StrSubstNo(ErrorMessage, PosTrans."POS Terminal No."));
                        end;
                    end;
                end;
            end;
        end;
    end;


    procedure UpdateOrderSales(OrderNo: Code[20])
    var
        DelOrder: Record "LSC Delivery Order";
        ProPosTrans: Record "LSC POS Transaction";
        TerminalNo: Code[10];
    begin
        //se actualiza la terminal
        if ProPosTrans.Get(OrderNo) then begin
            if DelOrder.Get(ProPosTrans."Receipt No.") then
                UpdateTerminalSales(ProPosTrans, TerminalNo);

        end;
    end;

    //se actualiza la terminal y se evalua si el pv es principal
    procedure UpdateTerminalSales(var ProPosTrans: Record "LSC POS Transaction"; TerminalNo: Code[10])
    var
        myInt: Integer;
        Terminal: Code[10];
    begin
        if TerminalNo <> '' then
            Terminal := TerminalNo
        else
            Terminal := POSSESSION.TerminalNo();
        if ProPosTrans."POS Terminal No." <> Terminal then
            UpdateTransactionTerminal(ProPosTrans."Receipt No.", Terminal, 0)
        else begin
            // se asigna el pedido a que pv se proceso y se actualiza a estado procesado
            ProPosTrans."FSN Assigned PosTerminalNo" := Terminal;
            ProPosTrans."FSN Status Robot" := ProPosTrans."FSN Status Robot"::Procesado;
            ProPosTrans."Staff ID" := POSSESSION.StaffID();
            ProPosTrans."FSN state of preparation" := ProPosTrans."FSN state of preparation"::Preparando;
            ProPosTrans.Modify(true);
        end;
    end;


}