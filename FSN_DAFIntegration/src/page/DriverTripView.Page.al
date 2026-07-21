page 50083 "FSN Driver Trip View"
{
    Caption = 'Driver Trip View';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = List;
    PromotedActionCategories = 'Admin,Trip,Reports,Orders';
    SourceTable = "FSN Delivery Trip";

    layout
    {
        area(content)
        {
            group(Status)
            {
                field(GeneralTripStatus; GeneralTripStatus)
                {
                    Editable = false;
                }
            }
            repeater(group)
            {
                field(OrderNo; ConvertOrderNo)
                {
                    Caption = 'Order No.';
                    Enabled = false;
                }
                field("Driver ID"; Rec."Driver ID")
                {
                    Caption = 'Driver ID';
                    Editable = false;
                    Visible = false;
                }
                field("Contact Name"; Rec."Contact Name")
                {
                    Caption = 'Contact Name';
                    Editable = false;
                }
                field("Order Amount"; Rec."Order Amount")
                {
                    Caption = 'Order Amount';
                    Editable = false;
                }
                field(Change; Rec.Change)
                {
                    Caption = 'Change';
                    Style = Strong;
                    StyleExpr = TRUE;

                    trigger OnValidate()
                    var
                        FSNDeliveryTrip: Record "FSN Delivery Trip";
                    begin

                        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                        IF InQueueMode OR (DeliveryDriverTrip.Status <> DeliveryDriverTrip.Status::Open) THEN
                            ERROR(Text6);

                        DelFuncExt.RecalctDriverAmtOnChangeFieldChange(Rec, Rec.Change, 0);
                        Rec.MODIFY;

                        DelFuncExt.UpdateValuesDelDriverTripExt(DeliveryDriverTrip);
                        DeliveryDriverTrip.MODIFY;
                        CurrPage.UPDATE;
                    end;
                }
                field(ToLiquidate; Rec."Trip Amount")
                {
                    Caption = 'To Liquidate';
                    Editable = true;

                    trigger OnValidate()
                    var
                        IText000: label 'Importe a liquidar no puede ser menor que el Importe de la Orden';
                    begin
                        if Rec."Payment Name" = 'Efectivo' then begin
                            if ("Trip Amount" > "Order Amount") or ("Trip Amount" = "Order Amount") then begin
                                Change := "Trip Amount" - "Order Amount";
                                CurrPage.Update(true);
                            end else begin
                                Message(IText000);
                                clear(Change);
                                clear("Trip Amount");
                            end;
                        end;
                    end;
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Caption = 'POS Terminal No.';
                    Editable = false;
                }
                field(Box; BoxText)
                {
                    Caption = 'Box';
                    Editable = false;
                    Style = Strong;
                    StyleExpr = 'Favorable';
                    Visible = Visible;
                }
                field("Payment Name"; Rec."Payment Name")
                {
                    Editable = false;
                }
                field("Phone No."; Rec."Phone No.")
                {
                    Caption = 'Phone No.';
                    Editable = false;
                }
                field("Trip. Status"; Rec."Trip. Status")
                {
                    Caption = 'Trip. Status';
                    Editable = false;
                    StyleExpr = StyleTxtStatus;
                    Visible = false;
                }
                field(TripType; CaptionTripType)
                {
                    Caption = 'Trip Type';
                    OptionCaption = 'Normal,DAF-Automatic';
                    Visible = false;
                }
                field("Street Name"; Rec."Street Name")
                {
                }
                field("Order Address"; Rec."Order Address")
                {
                }
            }
            group(Calculos)
            {
                Visible = VisibleTotals;
                field(OrdersAmount2; CalcTotalsSums)
                {
                    Caption = 'Orders Amount';
                }
                field(TotalChanges2; CalcTotalsChange)
                {
                    Caption = 'Total Changes';
                }
                field(TotalTrip; CalcTotalsSums + CalcTotalsChange)
                {
                    Caption = 'Total Trip';
                }
                field(DriverAmount; CalcDriverAmount)
                {
                    Caption = 'Amount to liquidate';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(Trip)
            {
                Caption = 'Trip';

                action(StartTrip)
                {
                    Caption = 'Start Trip';
                    Image = Continue;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTripStart;

                    trigger OnAction()
                    var
                        MesjConfirm: Text;
                        FSNParameter: Record "FSN Parameter";
                        TextConfirm: label 'Desea confirmar mercadería?';
                    begin
                        COMMIT;
                        IF Staff.GET(TripDriver) THEN;
                        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                        IF NOT DeliveryDriverTrip.FINDLAST THEN
                            EXIT
                        ELSE begin
                            if FSNParameter.Get('ROBOT', 'PROCESS') THEN BEGIN
                                IF FSNParameter.Activo then begin
                                    if FSNParameter.Get('ROBOT', 'PROCESSMERCA') then begin
                                        IF FSNParameter.Activo THEN BEGIN
                                            ValDelTrip(DeliveryDriverTrip);
                                            MesjConfirm := TextConfirm;
                                        end else
                                            MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");
                                    END ELSE
                                        MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");
                                end else
                                    MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");
                            end else
                                MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");

                            IF NOT CONFIRM(STRSUBSTNO(MesjConfirm)) THEN
                                EXIT;

                        end;

                        DeliveryDriverTrip.TESTFIELD("No. of Orders");

                        if FSNParameter.Get('ROBOT', 'PROCESS') THEN BEGIN
                            IF FSNParameter.Activo then
                                if FSNParameter.Get('ROBOT', 'PROCESSMERCA') then begin
                                    IF FSNParameter.Activo THEN
                                        MercaderyConfirm(DeliveryDriverTrip."DAF Trip No.", DeliveryDriverTrip."Driver ID");

                                end;
                        end;

                        DelFuncExt.SendTrip(DeliveryDriverTrip, 0);
                        //CurrPage.UPDATE;
                        CurrPage.CLOSE;
                    end;
                }

                action(StartTrip2)
                {
                    Caption = 'Confirmar ruta para cancelar pedido';
                    Image = Continue;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTripStartRobot;

                    trigger OnAction()
                    var
                        MesjConfirm: Text;
                        FSNParameter: Record "FSN Parameter";
                        TextConfirm: label 'Desea confirmar mercadería?';
                    begin

                        if ParameterRobot.Get('ROBOT', 'ACTIVEACTION') THEN
                            if ParameterRobot.Activo then begin
                                COMMIT;
                                IF Staff.GET(TripDriver) THEN;
                                FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                                IF NOT DeliveryDriverTrip.FINDLAST THEN
                                    EXIT
                                ELSE begin
                                    if FSNParameter.Get('ROBOT', 'PROCESSMERCA') and FSNParameter.Activo then begin
                                        if FSNParameter.Get('ROBOT', 'PROCESS') and FSNParameter.Activo then begin

                                            MesjConfirm := TextConfirm;
                                        end else
                                            MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");
                                    end else
                                        MesjConfirm := STRSUBSTNO(Text1, Staff."Name on Receipt");

                                    IF NOT CONFIRM(STRSUBSTNO(MesjConfirm)) THEN
                                        EXIT;

                                end;

                                DeliveryDriverTrip.TESTFIELD("No. of Orders");
                                if FSNParameter.Get('ROBOT', 'PROCESSMERCA') and FSNParameter.Activo then
                                    MercaderyConfirm(DeliveryDriverTrip."DAF Trip No.", DeliveryDriverTrip."Driver ID");
                                DelFuncExt.SendTrip2(DeliveryDriverTrip, 0);
                                //CurrPage.UPDATE;
                                CurrPage.CLOSE;
                            end;
                    end;
                }

                action(FinalizeTrip)
                {
                    Caption = 'Finalize Trip';
                    Image = ExportReceipt;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTripFinalize;

                    trigger OnAction()
                    begin
                        COMMIT;

                        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                        IF NOT DeliveryDriverTrip.FINDLAST THEN
                            EXIT
                        ELSE
                            IF NOT CONFIRM(STRSUBSTNO(Text2, DeliveryDriverTrip."No. of Orders")) THEN
                                EXIT;
                        MontoDAF();
                        DelFuncExt.SendTrip(DeliveryDriverTrip, 1);
                        AbrirCaja();
                        //CurrPage.UPDATE;
                        CurrPage.CLOSE;
                    end;
                }
                action(CancelTrip)
                {
                    Caption = 'Cancel Trip';
                    Image = Error;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTripCancel;

                    trigger OnAction()
                    begin
                        COMMIT;

                        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                        IF NOT DeliveryDriverTrip.FINDLAST THEN
                            EXIT
                        ELSE
                            IF NOT CONFIRM(STRSUBSTNO(Text3, rec."Driver Name")) THEN
                                EXIT;
                        DelFuncExt.SendTrip(DeliveryDriverTrip, 3);
                        AbrirCaja();
                        CurrPage.UPDATE;
                        CurrPage.CLOSE;
                    end;
                }
                action(AddFromQueue)
                {
                    Caption = 'Add From Queue';
                    Image = Add;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;
                    Visible = VisibleTQueue;
                    Ellipsis = true;

                    trigger OnAction()
                    var
                        PAGEViewOrderTrips: Page "FSN Driver Trip View";
                        LastRecord: Record "FSN Delivery Trip";
                    begin
                        COMMIT;
                        /*
                        DAF Origin Only
                        */
                        //MESSAGE(Text14);
                        //EXIT;

                        ValidateFunctionModeAutomatic;
                        DeliveryTrip.RESET;
                        DeliveryTrip.SETRANGE(DeliveryTrip."General Status", DeliveryTrip."General Status"::InQueue);
                        DeliveryTrip.SETRANGE(DeliveryTrip."Store No.", DeliveryDriverTrip."Store No.");
                        DeliveryTrip.SETRANGE(DeliveryTrip."Trip No. (LS Retail)", 0);
                        IF NOT DeliveryTrip.FINDLAST THEN BEGIN
                            MESSAGE(Text13);
                            EXIT;
                        END;
                        CLEAR(LastRecord);
                        PAGEViewOrderTrips.SetQueueMode(TripStore, TripDriver, TripNo);
                        PAGEViewOrderTrips.LOOKUPMODE(TRUE);
                        IF NOT (PAGEViewOrderTrips.RUNMODAL = ACTION::LookupOK) THEN
                            EXIT;
                        PAGEViewOrderTrips.GetLastSelction(LastRecord);

                        IF LastRecord."Order No." = '' THEN
                            EXIT;

                        IF NOT CONFIRM(STRSUBSTNO(Text5, LastRecord."Order No.", LastRecord."Contact No.", FORMAT(LastRecord."Order Amount"))) THEN
                            EXIT;

                        POSMenuLine.Command := 'ASSIGN_EXT';
                        POSMenuLine."Post Command" := 'FROMQUEUE';
                        POSMenuLine.Parameter := TripDriver;
                        POSMenuLine."Post Parameter" := TripDriver;
                        POSMenuLine."Current-RECEIPT" := LastRecord."Order No.";
                        DelFuncExt.RUN(POSMenuLine);

                        UpdateTxtGeneralStatus;
                        CurrPage.UPDATE;

                    end;
                }
                action(CreateTripFromDAF)
                {
                    Caption = 'CreateTripFromDAF';
                    Image = MapSetup;
                    Promoted = true;
                    PromotedCategory = Process;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        IF NOT DAF.CreateTripFromDAF(TripDriver, TripStore, TripNo, MsgReturn) THEN
                            MESSAGE(MsgReturn)
                        ELSE BEGIN
                            MESSAGE(STRSUBSTNO(Text11, MsgReturn));
                        END;
                        UpdateTxtGeneralStatus;
                    end;
                }
            }
            group("Order")
            {
                Caption = 'Order';
                action(UnAssign)
                {
                    Caption = 'UnAssign Order';
                    Image = CancelLine;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;
                    Visible = VisibleUn;

                    trigger OnAction()
                    begin
                        COMMIT;
                        //ValidateFunctionModeAutomatic;
                        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
                        IF DeliveryDriverTrip."Functionality Type" = DeliveryDriverTrip."Functionality Type"::Automatic THEN
                            IF CONFIRM(STRSUBSTNO(Text12, DeliveryDriverTrip.FIELDCAPTION("Functionality Type"), DeliveryDriverTrip."Functionality Type"::Automatic
                              , STRSUBSTNO(Text3, Staff."Name on Receipt"))) THEN BEGIN
                                DelFuncExt.SendTrip(DeliveryDriverTrip, 3);
                                CurrPage.UPDATE;
                                CurrPage.CLOSE;
                                EXIT;
                            END ELSE
                                EXIT;
                        DelFuncExt.UnAssignFromPageExt(Rec, 'QUITONLY', DeliveryDriverTrip);

                        UpdateTxtGeneralStatus;
                        CurrPage.UPDATE;
                    end;
                }
                action(ReOpenOrder)
                {
                    Caption = 'Re Open Orden';
                    Image = ChangeStatus;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;
                    Visible = VisibleReopen;

                    trigger OnAction()
                    begin
                        COMMIT;

                        //ValidateFunctionModeAutomatic;
                        IF NOT CONFIRM(STRSUBSTNO(Text4, Rec."Contact No.", Rec."Contact Name")) THEN
                            EXIT;

                        DelFuncExt.UnAssignFromPageExt(Rec, 'REOPEN', DeliveryDriverTrip);

                        MESSAGE(Text7);
                        //ValidateFunctionModeAutomatic;
                        IF DeliveryDriverTrip."No. of Orders" = 0 THEN BEGIN
                            DelFuncExt.SendTrip(DeliveryDriverTrip, 2);
                            CurrPage.UPDATE;
                            CurrPage.CLOSE;
                        END;
                        UpdateTxtGeneralStatus;
                        CurrPage.UPDATE;
                    end;
                }
                action(DeleteFromQueue)
                {
                    Caption = 'Delete From Queue';
                    Image = DeleteExpiredComponents;
                    Promoted = true;
                    PromotedCategory = Category4;
                    PromotedIsBig = true;
                    Visible = VisibleDeleteQueue;

                    trigger OnAction()
                    begin
                        COMMIT;
                        IF CONFIRM(STRSUBSTNO(Text8, Rec."Order No.", Rec."Phone No.", Rec."Trip Amount")) THEN
                            DelFuncExt.DeleteOrderFromQueue(Rec, 0);
                    end;
                }
                action(ViewMontoDAF)
                {
                    Caption = 'View Monto DAF';
                    Image = View;
                    Promoted = true;
                    PromotedCategory = Category5;
                    PromotedIsBig = true;

                    trigger OnAction()
                    begin
                        MontoDAF();
                    end;
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    var
        ParameterRobot: Record "FSN Parameter";
    begin
        CLEAR(ConvertOrderNo);
        /*CLEAR(StyleTxtStatus);
        IF "Trip. Status" = "Trip. Status"::"Trip Starting" THEN
          StyleTxtStatus := 'Favorable';*/
        IF STRLEN(Rec."Order No.") > 10 THEN
            ConvertOrderNo := COPYSTR(Rec."Order No.", 10)
        ELSE
            ConvertOrderNo := Rec."Order No.";

        if ParameterRobot.Get('ROBOT', 'ACTIVEACTION') then BEGIN
            IF ParameterRobot.Activo THEN
                BoxText := GetBox(Rec);
        end;
    end;

    trigger OnInit()
    begin
        VisibleReopen := TRUE;
        VisibleUn := TRUE;

        VisibleTripStart := TRUE;
        if ParameterRobot.Get('ROBOT', 'ACTIVEACTION') then BEGIN
            IF ParameterRobot.Activo THEN
                VisibleTripStartRobot := TRUE
            else
                VisibleTripStartRobot := FALSE
        END ELSE
            VisibleTripStartRobot := FALSE;

        VisibleTripFinalize := TRUE;
        VisibleTripCancel := TRUE;
        VisibleTQueue := TRUE;

        InQueueMode := FALSE;
        VisibleTotals := TRUE;
        VisibleDeleteQueue := FALSE;
        VisibleCreateFromDAF := FALSE;//STATIC
        CaptionTripType := 0;
    end;

    trigger OnOpenPage()
    var
        Staff_l: Record "LSC Staff";
        Parameter: Record "FSN Parameter";
        POSSESION: Codeunit "LSC POS Session";
        LabelText: Label 'Solo se puede liquidar moto en %1';
    begin

        /*if (Parameter.Get('ROBOT', 'PROCESS')) and Parameter.Activo then
            IF Parameter."Value Text 1" <> '' THEN
                if Parameter."Value Text 1" <> POSSESION.TerminalNo() THEN begin
                    Error(StrSubstNo(LabelText, Parameter."Value Text 1"));
                end;*/

        if (Parameter.Get('ROBOT', 'PROCESS')) then begin
            if Parameter.Activo then begin
                Visible := true;
            end else
                Visible := false;
            Visible := true;
        end else
            Visible := false;

        IF InQueueMode THEN BEGIN
            VisibleReopen := FALSE;
            VisibleUn := FALSE;
            VisibleTripStart := FALSE;
            VisibleTripFinalize := FALSE;
            VisibleTripCancel := FALSE;
            VisibleTQueue := FALSE;
            VisibleDeleteQueue := TRUE;

            VisibleTotals := FALSE;
            VisibleCreateFromDAF := FALSE;
            Rec.FILTERGROUP(2);
            Rec.SETRANGE("Trip No. (LS Retail)", 0);
            Rec.SETRANGE("Store No.", TripStore);
            Rec.SETRANGE("General Status", Rec."General Status"::InQueue);
            Rec.FILTERGROUP(0);
        END ELSE BEGIN
            DeliveryDriverTrip.RESET;
            DeliveryDriverTrip.SETCURRENTKEY(DeliveryDriverTrip."Driver ID", DeliveryDriverTrip."Store No.", DeliveryDriverTrip."Trip Counter");
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Driver ID", TripDriver);
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Store No.", TripStore);
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Trip Counter", TripNo);
            IF DeliveryDriverTrip.FINDFIRST THEN BEGIN
                IF DeliveryDriverTrip.Status = DeliveryDriverTrip.Status::Closed THEN BEGIN
                    VisibleUn := FALSE;
                    VisibleTripStart := FALSE;

                    VisibleTripStartRobot := FALSE;

                    VisibleTQueue := FALSE;
                    CurrPage.UPDATE := FALSE;
                    VisibleCreateFromDAF := FALSE;
                END ELSE BEGIN
                    VisibleReopen := FALSE;
                    VisibleTripFinalize := FALSE;
                    VisibleTripCancel := FALSE;
                END;
            END;
            IF Staff.GET(TripDriver) THEN;

            Rec.FILTERGROUP(2);
            Rec.SETRANGE("Trip No. (LS Retail)", TripNo);
            Rec.SETRANGE("Store No.", TripStore);
            Rec.SETRANGE("Driver ID", TripDriver);
            Rec.FILTERGROUP(0);
        END;
        UpdateTxtGeneralStatus;
    end;

    var
        AddToTrip: Boolean;
        TripNo: Integer;
        TripDriver: Code[20];
        TripStore: Code[10];
        DelFuncExt: Codeunit "FSN Delivery Func. Extend";
        Text1: Label 'Start trip?\Driver: %1';
        DeliveryTrip: Record "FSN Delivery Trip";
        DeliveryDriverTrip: Record "LSC Delivery Driver Trip";
        Text2: Label 'Motorcycle return?, \Finalize %1 orders?';
        Text3: Label 'Cancel trip for %1?';
        POSTransaction: Record "LSC POS Transaction";
        VisibleReopen: Boolean;
        Text4: Label 'Unassign order %1 %2?';
        VisibleUn: Boolean;
        StyleTxtStatus: Text[20];
        VisibleTripStart: Boolean;
        VisibleTripFinalize: Boolean;
        VisibleTripCancel: Boolean;
        VisibleTQueue: Boolean;
        InQueueMode: Boolean;
        Text5: Label 'Add order to trip?.\No. %1\Phone%2\Amount %3';
        POSMenuLine: Record "LSC POS Menu Line";
        Text6: Label 'Cant be modify';
        TotalAmount: Decimal;
        TotalChanges: Decimal;
        Text7: Label 'Sent to queue';
        VisibleTotals: Boolean;
        Text8: Label 'Cancel trip for order definitely. \Order%1\Phone %2 \Amount %3';
        VisibleDeleteQueue: Boolean;
        Text9: Label 'Trip was cancelled.';
        VisibleCreateFromDAF: Boolean;
        Text10: Label 'View Trip - Orders %1';
        DAF: Codeunit "FSN DAF Integration";
        MsgReturn: Text;
        Text11: Label 'Trip loaded! \%1';
        Text12: Label '%1 %2 %3';
        Staff: Record "LSC Staff";
        CaptionTripType: Option Normal,DAF;
        Text13: Label 'No orders in queue!';
        GeneralTripStatus: Text[100];
        ConvertOrderNo: Text[10];
        Text14: Label 'Cant be add order, DAF mode is active. ';

    procedure SetDriverID(pTrip: Integer; pDriver: Code[20]; pStore: Code[10])
    begin
        TripNo := pTrip;
        TripDriver := pDriver;
        TripStore := pStore;
    end;

    procedure FilterDeliveryDriverTrip(pDriver: Code[20]; pStore: Code[10]; pTripCount: Integer)
    begin
        DeliveryDriverTrip.GET(pDriver, pStore, pTripCount);
    end;

    procedure SetQueueMode(pStore: Code[10]; pDriver: Code[20]; pTripNo: Integer)
    begin
        TripNo := pTripNo;
        TripDriver := pDriver;
        TripStore := pStore;

        InQueueMode := TRUE;
    end;

    procedure GetLastSelction(var LastRec: Record "FSN Delivery Trip")
    begin
        LastRec := Rec;
    end;

    procedure CalcTotalsSums(): Decimal
    begin
        IF DeliveryDriverTrip.FINDLAST THEN;
        EXIT(DeliveryDriverTrip."Gross Amount");
    end;

    procedure CalcTotalsChange(): Decimal
    begin
        IF DeliveryDriverTrip.FINDLAST THEN;
        exit(DeliveryDriverTrip."Starting Float");
    end;

    procedure CalcDriverAmount(): Decimal
    begin
        IF DeliveryDriverTrip.FINDLAST THEN;
        EXIT(DeliveryDriverTrip."Driver Amount");
    end;

    procedure ValidateFunctionModeAutomatic()
    begin
        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
        IF DeliveryDriverTrip."Functionality Type" = DeliveryDriverTrip."Functionality Type"::Automatic THEN
            ERROR(STRSUBSTNO(Text12, Text6, DeliveryDriverTrip.FIELDCAPTION("Functionality Type"), FORMAT(DeliveryDriverTrip."Functionality Type")));
    end;

    procedure UpdateTxtGeneralStatus()
    begin
        FilterDeliveryDriverTrip(TripDriver, TripStore, TripNo);
        CaptionTripType := CaptionTripType::Normal;
        IF DeliveryDriverTrip."Functionality Type" = DeliveryDriverTrip."Functionality Type"::Automatic THEN
            CaptionTripType := CaptionTripType::DAF;

        IF InQueueMode THEN
            GeneralTripStatus := STRSUBSTNO(Text12, DeliveryTrip."General Status"::InQueue, '', '')
        ELSE
            CASE DeliveryDriverTrip.Status OF
                DeliveryDriverTrip.Status::Open:
                    GeneralTripStatus := STRSUBSTNO(Text12, Staff."Name on Receipt" + ':', DeliveryTrip."Trip. Status"::"Assigned Driver", CaptionTripType);
                DeliveryDriverTrip.Status::Closed:
                    GeneralTripStatus := STRSUBSTNO(Text12, Staff."Name on Receipt" + ':', DeliveryTrip."Trip. Status"::"Trip Starting", CaptionTripType);
                ELSE
                    GeneralTripStatus := STRSUBSTNO(Text12, Staff."Name on Receipt" + ':', DeliveryDriverTrip.Status, CaptionTripType);
            END;
    end;

    procedure AbrirCaja()
    var
        myInt: Integer;
        Process: DotNet Process;
        Ev: DotNet Environment;
        Parameter: Record "FSN Parameter";
    begin
        Parameter.Reset();
        Parameter.SetRange(Grupo, 'DRAWER');
        Parameter.SetRange(Codigo, 'OPEN');
        IF (Parameter.FindFirst()) AND (Parameter.Activo) THEN
            Process.Start('C:\Drawer\Release\OpenDrawer.exe');
    end;

    local procedure MessageAmount()
    var
        Total: Label 'Total Amount to liquidate is: %1';
        Change: Label 'Total Change is: $%1';
        Terminal: Label ' on Terminal: $%1';
        FSNDeliveryTrip: Record "FSN Delivery Trip";
    begin
        TotalAmount := DeliveryDriverTrip."Driver Amount";
        TotalChanges := DeliveryDriverTrip."Starting Float";
        MESSAGE(STRSUBSTNO(Total, FORMAT(TotalAmount)) + '\' + STRSUBSTNO(Change, FORMAT(TotalChanges) + '\' + STRSUBSTNO(Terminal, "POS Terminal No.")));
    end;

    procedure MontoDAF()
    var
        PosCashDeclTmp: Record "LSC POS Cash Declaration" temporary;
        PosCashDecChanlTmp: Record "LSC POS Cash Declaration" temporary;
        DeliveryDriverTrip: Record "LSC Delivery Driver Trip";
        DeliveryTrip_l: Record "FSN Delivery Trip";
        TransHeader: Record "LSC Transaction Header";
        PayEntry: Record "LSC Trans. Payment Entry";
        FSNParameter: Record "FSN Parameter";
    begin

        if FSNParameter.Get('DAF', 'PAYMENT') and FSNParameter.Activo then begin
            DeliveryDriverTrip.RESET;
            DeliveryDriverTrip.SETCURRENTKEY(DeliveryDriverTrip."Driver ID", DeliveryDriverTrip."Store No.", DeliveryDriverTrip."Trip Counter");
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Driver ID", TripDriver);
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Store No.", TripStore);
            DeliveryDriverTrip.SETRANGE(DeliveryDriverTrip."Trip Counter", TripNo);
            if DeliveryDriverTrip.Find('-') then begin
                repeat
                    DeliveryTrip_l.RESET;
                    DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Store No.", DeliveryDriverTrip."Store No.");
                    DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Driver ID", DeliveryDriverTrip."Driver ID");
                    DeliveryTrip_l.SETRANGE(DeliveryTrip_l."Trip No. (LS Retail)", DeliveryDriverTrip."Trip Counter");
                    if DeliveryTrip_l.Find('-') then begin
                        repeat
                            TransHeader.RESET;
                            TransHeader.SETRANGE(TransHeader."Store No.", DeliveryTrip_l."Store No.");
                            TransHeader.SETRANGE(TransHeader."Receipt No.", DeliveryTrip_l."Order No.");
                            if TransHeader.FindFirst() then begin
                                PayEntry.RESET;
                                PayEntry.SETRANGE(PayEntry."Store No.", TransHeader."Store No.");
                                PayEntry.SETRANGE(PayEntry."Transaction No.", TransHeader."Transaction No.");
                                PayEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
                                if PayEntry.FindFirst() then begin
                                    repeat
                                        if (PayEntry."Tender Type" = '1') and (PayEntry."Change Line" = true) then begin
                                            if PosCashDecChanlTmp.Get(PayEntry."POS Terminal No.", PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") AND (PosCashDecChanlTmp."POS Terminal No." = PayEntry."POS Terminal No.") then begin
                                                PosCashDecChanlTmp."Trans. Amount" := PosCashDecChanlTmp."Trans. Amount" + PayEntry."Amount in Currency";
                                                PosCashDecChanlTmp.Modify;
                                            end else begin
                                                Clear(PosCashDecChanlTmp);
                                                PosCashDecChanlTmp."Tender Type" := PayEntry."Tender Type";
                                                PosCashDecChanlTmp."Currency Code" := PayEntry."Currency Code";
                                                PosCashDecChanlTmp."Card No." := PayEntry."Card No.";
                                                PosCashDecChanlTmp."Trans. Amount" := PayEntry."Amount in Currency";
                                                PosCashDecChanlTmp."POS Terminal No." := PayEntry."POS Terminal No.";
                                                if not PosCashDecChanlTmp.Insert then
                                                    PosCashDecChanlTmp.Modify();
                                            end;
                                        end else
                                            if PosCashDeclTmp.Get(PayEntry."POS Terminal No.", PayEntry."Tender Type", PayEntry."Currency Code", PayEntry."Card No.") and (PosCashDeclTmp."POS Terminal No." = PayEntry."POS Terminal No.") then begin
                                                PosCashDeclTmp."Trans. Amount" := PosCashDeclTmp."Trans. Amount" + PayEntry."Amount in Currency";
                                                PosCashDeclTmp.Modify;
                                            end
                                            else begin
                                                Clear(PosCashDeclTmp);
                                                PosCashDeclTmp."Tender Type" := PayEntry."Tender Type";
                                                PosCashDeclTmp."Currency Code" := PayEntry."Currency Code";
                                                PosCashDeclTmp."Card No." := PayEntry."Card No.";
                                                PosCashDeclTmp."Trans. Amount" := PayEntry."Amount in Currency";
                                                PosCashDeclTmp."POS Terminal No." := PayEntry."POS Terminal No.";
                                                if not PosCashDeclTmp.Insert then
                                                    PosCashDeclTmp.Modify();
                                            end;
                                    until PayEntry.Next() = 0;
                                end;
                            end;
                        until DeliveryTrip_l.Next = 0;
                    end;
                until DeliveryDriverTrip.Next = 0;
                GenerateMontoDAFHTML(PosCashDeclTmp, PosCashDecChanlTmp);
            end;
        end;
    end;

    procedure GenerateMontoDAFHTML(var PosCashDeclTmp: Record "LSC POS Cash Declaration" temporary; var PosCashDecChanlTmp: Record "LSC POS Cash Declaration" temporary): Text
    var
        HTML: Text;
        ChangeAmount: Decimal;
        TotalAmount: Decimal;
        MontosHTML, THTextVal : Text;
        TitleLabel: Label 'MONTOS DE LIQUIDACION DAF';
        Url: Text;
        PageImagen: Page TextCopy;
    begin
        HTML := '<table border="1"><tr><th>Media de Pago</th><th>Monto</th><th>Cambio</th><th>Total</th></tr>';

        if PosCashDeclTmp.FindSet() then
            repeat
                // Buscar el cambio correspondiente
                PosCashDecChanlTmp.SetRange("Tender Type", PosCashDeclTmp."Tender Type");
                PosCashDecChanlTmp.SetRange("Currency Code", PosCashDeclTmp."Currency Code");
                PosCashDecChanlTmp.SetRange("Card No.", PosCashDeclTmp."Card No.");
                PosCashDecChanlTmp.SetRange("POS Terminal No.", PosCashDeclTmp."POS Terminal No.");
                if PosCashDecChanlTmp.FindFirst() then
                    ChangeAmount := PosCashDecChanlTmp."Trans. Amount"
                else
                    ChangeAmount := 0;

                TotalAmount := PosCashDeclTmp."Trans. Amount" + ChangeAmount;
                MontosHTML += '<tr>' +
                                    '<td>' + TtendeType(PosCashDeclTmp."Tender Type") + '</td>' +
                                    '<td>' + PosCashDeclTmp."POS Terminal No." + '</td>' +
                                    '<td>' + ' $ ' + Format(PosCashDeclTmp."Trans. Amount", 0, '<Precision,2:2><Standard Format,0>') + '</td>' +
                                    '<td>' + ' $ ' + Format(ChangeAmount, 0, '<Precision,2:2><Standard Format,0>') + '</td>' +
                                    '<td>' + ' $ ' + Format(TotalAmount, 0, '<Precision,2:2><Standard Format,0>') + '</td>';
                MontosHTML += '</tr>';
            until PosCashDeclTmp.Next() = 0;

        THTextVal := '<tr>' +
                            '<th>Media de Pago</th>' +
                            '<th>Terminal</th>' +
                            '<th>Monto</th>' +
                            '<th>Cambio</th>' +
                            '<th>Total</th>' +
                            '</tr>';

        Url := GenerateHTML(MontosHTML, THTextVal, TitleLabel);

        PageImagen.CopyTxt(Url);
        PageImagen.Run();
        EXIT;
    end;

    local procedure TtendeType(Med: Code[20]): Text
    var
        tenderType: Record "LSC Tender Type";
    begin
        tenderType.Reset();
        if tenderType.Get(TripStore, Med) then
            EXIT(tenderType.Description);
        EXIT('');
    end;

    procedure GenerateHTML(TDText: Text; THText: Text; Title: text): Text
    begin


        exit(
            '<!DOCTYPE html>' +
            '<html lang="en">' +
            '<head>' +
            '    <meta charset="UTF-8">' +
            '    <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '    <title>DAF</title>' +
            '   <style> ' +
            '       .scrollable-table {' +
            '           width: 99%;' +
            '           max-height: 400px;' +
            '           overflow-y: auto;' +
            '           border: 1px solid #ccc;' +
            '       }' +

            /*'         .table-title {' +
            '            background-color: #0097a2;' +
            '            padding: 10px;' +
            '            font-size: 25px;' +
            '            font-weight: bold;' +
            '            color: white;' +
            '            text-align: center;' +
            '        }' +*/


            '       table {' +
            '           width: 100%;' +
            '           border-collapse: collapse;' +
            '       }' +

            '       th, td {' +
            '           padding: 8px;' +
            '           border: 1px solid #999;' +
            '           text-align: center;' +
            '           z-index: 0;' +
            '       }' +

             '       .table-title {' +
             '           position: sticky;' +
             '           top: 0;' +
             '           background-color: #0097a2;' +
             '           padding: 8px;' +
             '           font-size: 15px;' +
             '           font-weight: bold;' +
             '           color: white;' +
             '           z-index: 0;' +
             '           border-bottom: 1px solid #ccc;' +
             '       }' +

            '        thead th {' +
            '           position: sticky;' +
             '           top: 35px;' +
             '           background-color: #0097a2;' +
             '           padding: 8px;' +
             '           font-size: 15px;' +
             '           font-weight: bold;' +
             '           color: white;' +
             '           z-index: 0;' +
             '           border-bottom: 1px solid #ccc;' +
            '        }' +

            '        body { font-family: Arial, sans-serif; margin: 20px; text-align: center; }' +
            '        caption, strong, { background-color: #0097a2; color: white; padding: 8px; border: 1px solid #999; }' +
            '   </style>' +
            '</head>' +
            '<body>' +
            '   <div class="scrollable-table">' +
            '   <div class="table-title">' + Title + '</div>' +
            '        <table>' +
            '           <thead>' +
                           THText +
            '           </thead>' +
            '          <tbody>' + TDText +
            '          </tbody>' +
            '       </table>' +
            '   </div>' +
            '</body>' +
            '</html>'
        );
    end;

    procedure ValDelTrip(DelDriveTRip: Record "LSC Delivery Driver Trip")
    var
        myInt: Integer;
        DelTrip: Record "FSN Delivery Trip";
        DelTripUpdate: Record "FSN Delivery Trip";
        TransHdr: Record "LSC Transaction Header";
        FSNParameter: Record "FSN Parameter";
        Txt3: Label 'El pedido debe ser facturado.\%1\%2\%3';
    begin
        if FSNParameter.Get('ROBOT', 'PROCESS') then begin
            DelTrip.Reset();
            DelTrip.SetRange("Store No.", DelDriveTRip."Store No.");
            DelTrip.SetRange("Driver ID", DelDriveTRip."Driver ID");
            DelTrip.SetRange("Trip No. (LS Retail)", DelDriveTRip."Trip Counter");
            IF DelTrip.Find('-') THEN BEGIN
                repeat
                    TransHdr.Reset();
                    TransHdr.SetRange(TransHdr."Receipt No.", DelTrip."Order No.");
                    IF TransHdr.FindFirst() then BEGIN
                        IF DelTrip."POS Terminal No." <> TransHdr."POS Terminal No." THEN begin
                            DelTripUpdate.Reset();
                            DelTripUpdate.SetRange(DelTripUpdate."Store No.", DelDriveTRip."Store No.");
                            DelTripUpdate.SetRange(DelTripUpdate."Driver ID", DelDriveTRip."Driver ID");
                            DelTripUpdate.SetRange(DelTripUpdate."Trip No. (LS Retail)", DelDriveTRip."Trip Counter");
                            DelTripUpdate.SetRange(DelTripUpdate."Order No.", DelTrip."Order No.");
                            if DelTripUpdate.FindFirst() then begin
                                DelTripUpdate."POS Terminal No." := TransHdr."POS Terminal No.";
                                DelTripUpdate.Modify();
                            end;
                        end;
                    END ELSE
                        ERROR(STRSUBSTNO(Txt3, DelTrip."Order No.", DelTrip."Phone No.", DelTrip."Order Amount"));
                until DelTrip.Next() = 0;
            END;
        end;
    end;

    local procedure getCredentials(): Text
    var
        Api: Codeunit "DTE API Connection";
        parameter: Record "FSN Parameter";
        credentialObject: JsonObject;
        credentialResult: JsonObject;
        body: HttpContent;
        headers: HttpHeaders;
        request: HttpRequestMessage;
        uri: Text;
        sBody: JsonToken;
        sData: JsonToken;
        sToken: JsonToken;
    begin
        if parameter.Get('DAF', 'DAF_API') then begin
            body.GetHeaders(headers);
            headers.Clear();
            headers.Add('Content-Type', 'application/json');
            request.Content := body;
            uri := parameter."Web Uri" + '/api/Route/ReceivedMerchandiseStoreNAV';
            credentialResult := Api.Post(uri, request);
            IF credentialResult.SelectToken('body', sBody) then
                IF sBody.SelectToken('data', sData) then
                    IF sData.AsObject().SelectToken('token', sToken) then exit(sToken.AsValue().AsText())
        end;
    end;

    procedure MercaderyConfirm(idRoute: Integer; idMotorcyclist: Text)
    var
        json: JsonObject;
        CodeResult: Integer;
        MessageError: Text;

    begin
        json.Add('idRoute', idRoute);
        json.Add('idMotorcyclist', idMotorcyclist);

        SendInformation(Format(json), CodeResult, MessageError);
    end;

    procedure SendInformation(pBody: Text; var CodeResultS: Integer; var MessageError: Text): Text
    var

        JToken: DotNet JToken;
        RESPONSEGLOBAL: Text;
        BODYGLOBAL: Text;
        SRFREQUEST: Text;
        SRFBANVALUE: Text;
        requestHeader, contentHeader : HttpHeaders;
        body: HttpContent;
        request: HttpRequestMessage;
        response: JsonObject;
        token: JsonToken;
        FSNParameter: Record "FSN Parameter";
        DAFIntegration: Codeunit "FSN DAF Integration";
        Credentials: text;
    begin
        IF FSNParameter.Get('DAF', 'DAF_API') and FSNParameter.Activo then begin
            BODYGLOBAL := pBody;
            SRFREQUEST := FSNParameter."Web Uri" + 'Route/ReceivedMerchandiseStoreNAV';
            SRFBANVALUE := FSNParameter."Web Action";

            Credentials := DAFIntegration.getCredentials();

            RESPONSEGLOBAL := '';
            //NEW
            body.WriteFrom(pBody);
            body.GetHeaders(contentHeader);
            contentHeader.Clear();
            contentHeader.Add('Content-Type', FSNParameter."Web Action");
            request.GetHeaders(requestHeader);
            requestHeader.Clear();
            request.Content := body;
            requestheader.Add('Authorization', 'Bearer ' + Credentials);

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

    procedure GetBox(FSNDelTrip: Record "FSN Delivery Trip"): Text
    var
        InfoPosEntry: Record "LSC POS Trans. Infocode Entry";
        InfoTransEntry: Record "LSC Trans. Infocode Entry";
        TransactionHeader: Record "LSC Transaction Header";
        POSTrans: Record "LSC POS Transaction";

    begin
        if POSTrans.get(FSNDelTrip."Order No.") then begin
            InfoPosEntry.Reset();
            InfoPosEntry.SetRange(InfoPosEntry."Store No.", POSTrans."Store No.");
            InfoPosEntry.SetRange(InfoPosEntry."POS Terminal No.", POSTrans."POS Terminal No.");
            InfoPosEntry.SetRange(InfoPosEntry."Receipt No.", POSTrans."Receipt No.");
            InfoPosEntry.SetRange(InfoPosEntry.Infocode, 'TEXT');
            InfoPosEntry.SetRange(InfoPosEntry."Line No.", 80);
            if InfoPosEntry.FindFirst() then
                exit(COPYSTR('CAJA' + ' ' + InfoPosEntry.Information, 1, 30));
        end;

        TransactionHeader.Reset();
        TransactionHeader.SetRange(TransactionHeader."Receipt No.", fsndelTrip."Order No.");
        if TransactionHeader.FindFirst() then begin
            InfoTransEntry.Reset();
            InfoTransEntry.SetRange(InfoTransEntry."Store No.", TransactionHeader."Store No.");
            InfoTransEntry.SetRange(InfoTransEntry."POS Terminal No.", TransactionHeader."POS Terminal No.");
            InfoTransEntry.SetRange(InfoTransEntry."Transaction No.", TransactionHeader."Transaction No.");
            InfoTransEntry.SetRange(InfoTransEntry.Infocode, 'TEXT');
            InfoTransEntry.SetRange(InfoTransEntry."Line No.", 80);
            if InfoTransEntry.FindFirst() then
                exit(COPYSTR('CAJA' + ' ' + InfoTransEntry.Information, 1, 30));
        end;

        exit('--');
    end;

    var
        CaptionText: label 'Confirmar mercadería';
        CaptionStartShip: label 'Iniciar viaje';
        CaptionValue: text;
        ParameterRobot: Record "FSN Parameter";
        VisibleTripStartRobot: Boolean;
        Visible: Boolean;
        BoxText: text;

}

