page 50122 "FSN PITS Whse Receipt Card"
{
    Caption = 'Recepción de Almacén - PITS';
    DeleteAllowed = false;
    Editable = true;
    PageType = Document;
    PopulateAllFields = true;
    PromotedActionCategories = 'New,Process,Report,Print/Send,Posting,Receipt,Navigate,Prepare';
    RefreshOnActivate = true;
    SourceTable = "Warehouse Receipt Header";

    layout
    {
        area(content)
        {
            group(General)
            {
                Caption = 'General';
                field("No."; "No.")
                {
                    ApplicationArea = Warehouse;
                    ToolTip = 'Número de recepción generado automáticamente';
                    Editable = false;
                    trigger OnAssistEdit()
                    begin
                        if AssistEdit(xRec) then
                            CurrPage.Update();
                    end;

                }
                field("Location Code"; "Location Code")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                    ToolTip = 'Código de almacén donde se reciben los artículos';
                    trigger OnValidate()
                    var
                        myInt: Integer;
                    begin
                        /*if "Location Code" = 'F13' then
                            VisibleAction := true
                        else
                            VisibleAction := false;*/
                    end;
                }
                field("Vendor Shipment No."; "Vendor Shipment No.")
                {
                    ApplicationArea = Warehouse;
                    Editable = true;
                    ToolTip = 'DTE / Número de remisión';
                }
                field("FSN External Document No."; "FSN External Document No.")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                    ToolTip = 'Número de Transferencia (TR)';
                }
                field("Posting Date"; "Posting Date")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                    ToolTip = 'Fecha de registro';
                }
                field("Assignment Date"; "Assignment Date")
                {
                    ApplicationArea = Warehouse;
                    Editable = false;
                    ToolTip = 'Fecha de asignación';
                }
                field("FSN Estado Transferencia"; EstadoTransferencia)
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Estado Transferencia';
                    Editable = false;
                    ToolTip = 'Estado actual del proceso de transferencia';
                    StyleExpr = EstadoStyle;
                }
            }
            part(PITSLines; "FSN PITS Whse Receipt Lines")
            {
                ApplicationArea = Warehouse;
                SubPageLink = "FSN Warehouse Receipt No." = FIELD("No.");
            }
        }
        area(factboxes)
        {
            systempart(Control1900383207; Links)
            {
                ApplicationArea = RecordLinks;
                Visible = false;
            }
            systempart(Control1905767507; Notes)
            {
                ApplicationArea = Notes;
                Visible = true;
            }
        }
    }

    actions
    {
        area(navigation)
        {
            group("&Receipt")
            {

            }
        }
        area(processing)
        {
            group("P&osting")
            {
                Caption = 'P&osting';
                Image = Post;
                action("Registrar")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Registrar';
                    Image = Post;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ToolTip = 'Marcar el WR como AplicandoAutomatico para su publicación vía SOAP';

                    trigger OnAction()
                    var
                        ConfirmMsg: Label '¿Desea marcar el WR %1 como AplicandoAutomatico?';
                        SuccessMsg: Label 'WR %1 marcado como AplicandoAutomatico.';
                        Errorline: Label 'No se pueden registrar WR con líneas pendientes de escanear.';

                    begin
                        //ValidateScan();

                        if Rec.Status = Rec.Status::AplicandoAutomatico then
                            exit;

                        if not Confirm(ConfirmMsg, false, "No.") then
                            exit;

                        Rec.Status := Rec.Status::AplicandoAutomatico;
                        Rec.Modify(true);
                        Message(SuccessMsg, "No.");
                    end;
                }
                action("Registrar e imprimir")
                {
                    ApplicationArea = Warehouse;
                    Caption = 'Registrar e imprimir';
                    Image = PostPrint;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    ToolTip = 'Marca el WR como AplicandoAutomatico y abre la ventana de impresión del reporte de recepción.';

                    trigger OnAction()
                    var
                        ConfirmMsg: Label '¿Desea marcar el WR %1 como AplicandoAutomatico?';
                        SuccessMsg: Label 'WR %1 marcado como AplicandoAutomatico.';
                        WhseRcptHeader: Record "Warehouse Receipt Header";
                    begin

                        //ValidateScan();

                        if Rec.Status <> Rec.Status::AplicandoAutomatico then begin
                            if not Confirm(ConfirmMsg, false, "No.") then
                                exit;

                            Rec.Status := Rec.Status::AplicandoAutomatico;
                            Rec.Modify(true);
                            Message(SuccessMsg, "No.");
                        end;

                        COMMIT;

                        WhseRcptHeader.Reset();
                        WhseRcptHeader.SetRange("No.", Rec."No.");
                        Report.RunModal(Report::"FSN Reception Direct", true, true, WhseRcptHeader);
                    end;
                }
                // Acción "Registrar Transferencia" eliminada por nuevo flujo vía SOAP/JSON
            }

            /*action(albaran)
            {
                Caption = 'Procesar Albarán';
                ApplicationArea = All;
                Visible = VisibleAction;

                trigger OnAction()
                var
                    json: JsonObject;
                    array: JsonArray;
                    CodeResult: Integer;
                    errorMessage: Text;
                    ReponseText: Text;
                    jObject: JsonObject;
                    jToken: JsonToken;
                    PITSWMScd2suc: Record "PITS_WMScd2suc";
                begin

                    array := getProductListAlbaran(Rec."FSN External Document No.", Rec."No.");
                    json.Add('deliveryNumber', Rec."No.");
                    json.Add('lines', array);
                    ReponseText := SentInfotmationAlbaran(Format(json), CodeResult, errorMessage);
                    if jObject.ReadFrom(ReponseText) then begin
                        //Muestra el mensaje de la API
                        if jObject.Get('message', jToken) then BEGIN
                            Message('ROBOT:' + ' ' + jToken.AsValue().AsText());
                            CurrPage.Update();
                        END;
                    END;

                end;
            }*/
            action(Scanner)
            {
                ApplicationArea = All;
                Caption = 'Scanner';
                Promoted = true;
                PromotedIsBig = true;
                PromotedCategory = Process;
                Image = BarCode;
                Visible = VisibleAction;

                trigger OnAction()
                var
                    PageScanner: Page "FSN Whse Receipt by Scanner";
                    WarehRecHeader: Record "Warehouse Receipt Header";
                    lTextMenu: Label '&Documento,&Pedido';//Documento WR Pedido TR
                    TEXT000: Label 'Debe selecionar Documento o Pedido';
                    IDSelected: Integer;
                    IsTypeDocument: Boolean;
                begin

                    IDSelected := STRMENU(lTextMenu, 0);

                    if IDSelected = 0 then
                        exit;

                    Clear(PageScanner);

                    if IDSelected = 1 then
                        PageScanner.SetPurchOrderNo(Rec."No.", Rec."Location Code")
                    else
                        PageScanner.SetPurchOrderNoPed(Rec."FSN External Document No.", Rec."Location Code");

                    PageScanner.RunModal();
                end;
            }
        }
    }

    var
        EstadoTransferencia: Text[30];
        EstadoStyle: Text;

    trigger OnAfterGetRecord()
    begin
        ActualizarEstadoTransferencia();
    end;

    trigger OnOpenPage()
    var
        WMSManagement: Codeunit "WMS Management";
    begin

        Param.Reset();
        Param.SetRange(Grupo, 'ROBOTSTORE');
        Param.SetRange(Codigo, "Location Code");
        IF Param.FindFirst() then begin
            if Param.Activo then begin
                VisibleAction := true;
                CurrPage.PITSLines.PAGE.ValidateMachine(VisibleAction);
                CurrPage.PITSLines.PAGE.Update();
            end else begin
                VisibleAction := false;
                CurrPage.PITSLines.PAGE.ValidateMachine(VisibleAction);
                CurrPage.PITSLines.PAGE.Update();
            end;
        end else begin
            VisibleAction := false;
            CurrPage.PITSLines.PAGE.ValidateMachine(VisibleAction);
            CurrPage.PITSLines.PAGE.Update();
        end;


        FilterGroup(2);
        SetFilter("Location Code", WMSManagement.GetWarehouseEmployeeLocationFilter(UserId));
        FilterGroup(0);
    end;

    local procedure ActualizarEstadoTransferencia()
    var
        PITSLine: Record PITS_WMScd2suc;
        EstadoActual: Integer;
    begin
        EstadoTransferencia := 'Sin Datos';
        EstadoStyle := 'Subordinate';

        // Buscar el estado de las líneas PITS asociadas a este WR
        PITSLine.RESET;
        PITSLine.SETRANGE("FSN Warehouse Receipt No.", "No.");
        if PITSLine.FINDFIRST then begin
            EstadoActual := PITSLine."FSN TransferHistorico";

            case EstadoActual of
                0: // Abierto
                    begin
                        EstadoTransferencia := 'Abierto';
                        EstadoStyle := 'None';
                    end;
                1: // Lanzado
                    begin
                        EstadoTransferencia := 'Lanzado';
                        EstadoStyle := 'StandardAccent';
                    end;
                2: // Registrado
                    begin
                        EstadoTransferencia := 'Registrado';
                        EstadoStyle := 'Attention';
                    end;
                3: // Histórico
                    begin
                        EstadoTransferencia := 'Histórico';
                        EstadoStyle := 'Favorable';
                    end;
                4: // WR Eliminado
                    begin
                        EstadoTransferencia := 'WR Eliminado';
                        EstadoStyle := 'Unfavorable';
                    end;
            end;
        end;
    end;

    procedure getProductListAlbaran(DocumentNo: Code[30]; FSNWR: Code[20]): JsonArray
    var
        PITSWMScd2suc: Record "PITS_WMScd2suc";
        RecItem: Record Item;
        json: JsonObject;
        array: JsonArray;
        Text000: Label 'No hay items que cumplan con los criterios de búsqueda';
        Text001: Label 'No se encontraron items para Albaran';
        intValue: Integer;
    begin


        PITSWMScd2suc.SetRange(PITSWMScd2suc."No.", DocumentNo);
        PITSWMScd2suc.SetRange(PITSWMScd2suc."FSN Warehouse Receipt No.", FSNWR);
        if PITSWMScd2suc.Find('-') then begin
            repeat
                Clear(json);
                intValue := PITSWMScd2suc."Qty. to Ship";
                json.Add('productId', PITSWMScd2suc."Item No.");
                json.Add('packagingUnit', PITSWMScd2suc."Unit of Measure");
                json.Add('expirationDate', PITSWMScd2suc."Expiration Date");
                json.Add('quantity', intValue);
                array.Add(json.AsToken());
            until PITSWMScd2suc.Next() = 0;
            exit(array);
        end else
            Error(Text001);
    end;

    procedure SentInfotmationAlbaran(pBody: Text; var CodeResultS: Integer; var MessageError: Text): Text
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
        FSNParameter: Record "FSN Parameter";
    begin

        IF FSNParameter.Get('ROBOT', 'PROCESSLIST') and FSNParameter.Activo then begin
            SRFREQUEST := FSNParameter."Web Uri" + 'Order/SendStockDelivery';
            SRFBANVALUE := FSNParameter."Web Action";

            RESPONSEGLOBAL := '';
            body.WriteFrom(pBody);
            body.GetHeaders(contentHeader);
            contentHeader.Clear();
            contentHeader.Add('Content-Type', FSNParameter."Web Action");
            request.GetHeaders(requestHeader);
            requestHeader.Clear();
            request.Content := body;

            response := Post(SRFREQUEST, request, CodeResultS, MessageError);
            exit(Format(response));
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

    procedure ValidateScan(): Boolean
    var
        FSNParameter: Record "FSN Parameter";
        PITSWMScd2sucLine: Record PITS_WMScd2suc;
        Errorline: Label 'No se pueden registrar WR con líneas pendientes de escanear.';
    begin
        FSNParameter.Reset();
        FSNParameter.SetRange(Grupo, 'ROBOT');
        FSNParameter.SetRange(Codigo, 'STORE');
        FSNParameter.SetRange(Valor, "Location Code");
        IF FSNParameter.FindFirst() then begin
            PITSWMScd2sucLine.Reset();
            PITSWMScd2sucLine.SetRange(PITSWMScd2sucLine."FSN Warehouse Receipt No.", Rec."No.");
            PITSWMScd2sucLine.SetRange(PITSWMScd2sucLine."Ajuste Pasado", false);
            if PITSWMScd2sucLine.FindFirst() then
                Error(Errorline);
        END;
    end;

    var
        VisibleAction: Boolean;
        Param: Record "FSN Parameter";
}
