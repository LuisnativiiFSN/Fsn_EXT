
codeunit 50091 ChangeEventHosp
{
    SingleInstance = true;
    trigger OnRun()
    begin

    end;

    var
        p: Page "FSN Take Order CC";
        hosp: Codeunit "LSC Hospitality POS Startup";
        post: Codeunit "LSC POS Transaction";
        delo: codeunit "LSC Delivery Order Management";
        pos: codeunit "LSC POS Controller";
        price: codeunit "LSC Retail Price Utils";
        CustomerCC: Code[20];
        IsActive: Boolean;
        POSSESSION: Codeunit "LSC POS Session";
        DomicilioTake2: Option Home,Work,Other,Takeout;
        RetailSetup: Record "LSC Retail Setup";
        Store: Record "LSC Store";
        PosFuncProfile: Record "LSC POS Func. Profile";

    /***********************************************************************************************************************/
    /* CALL CENTER & HOSPITALITY */
    /***********************************************************************************************************************/
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC Hospitality POS Startup", 'OnBeforeExecuteCommand', '', true, true)]
    local procedure "LSC Hospitality POS Startup_OnBeforeExecuteCommand"
    (
        MenuLine: Record "LSC POS Menu Line";
        CurrentReceipt: Code[20];
        var CommandRun: Boolean;
        var HospitalityTypeTemp: Record "LSC Hospitality Type";
        ActiveDiningArea: Record "LSC Dining Area";
        ActiveServiceFlow: Record "LSC Hospitality Service Flow";
        var IsHandled: Boolean
    )
    var
        delOrder: Record "LSC Delivery Order";
        DelContAdd_l: Record "LSC Delivery Contact Address";
        Contact_l: Record Contact;
        storeFromContact: Boolean;
        posTrans: Record "LSC POS Transaction";
        POSSESSION: Codeunit "LSC POS Session";
        userRetail: Record "LSC Retail User";
        TransactionUse: Record "LSC Transaction in Use on POS";
    //retailSetup: Record "LSC Retail Setup";
    begin
        //toreFromContact := false;
        /*if (MenuLine.Command = 'DELIVERY') and (MenuLine.Parameter <> '') then begin
            delOrder.Reset();
            delOrder.SetRange("Phone No.", MenuLine.Parameter);
            if not delOrder.FindFirst() then
                if Contact_l.Get(delOrder."Phone No.") then
                    if DelContAdd_l.Get(delOrder."Phone No.", DelContAdd_l."Address Type"::Home) then begin
                        possession.SetTempStoreTerminal(userRetail."Store No.", userRetail."POS Terminal", '');
                        storeFromContact := true;
                    end;
        end;*/

        RetailSetup.Get;
        if RetailSetup."FSN Is Local Receipt" then begin //IS CALLCENTER

            if not (MenuLine.Command IN ['DELEDIT', 'DEL-CHEK-PHONE', 'DELIVERY', 'HOSP-ORDER-EDIT', 'HOSP-SEARCHRESET', 'CTI', 'PHONEFSN']) then
                exit;
            if IsHandled then
                exit;
            if not storeFromContact then
                if userRetail.get(UserId) then begin
                    possession.SetTempStoreTerminal(userRetail."Store No.", userRetail."POS Terminal", '');
                end;

            IsActive := true;
            TransactionUse.Reset();
            TransactionUse.SetRange("User ID", UserId);
            TransactionUse.DeleteAll();
            /*if RetailSetup."FSN Is Local Receipt" then
                if posTrans.get(POSSESSION.GetValue('CURRORDER')) then
                    if posTrans."Sales Staff" = '' then
                        if delOrder.Get(posTrans."Receipt No.") and (delOrder."Order Taker" <> '') then begin
                            posTrans."Sales Staff" := delOrder."Order Taker";
                            posTrans.Modify();
                        end;
                        */
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSCommand', '', true, true)]
    local procedure "EPOS Controler_OnPOSCommand"
    (
        var ActivePanel: Record "LSC POS Panel";
        var PosMenuLine: Record "LSC POS Menu Line"
    )
    var
        deliverOr: Record "LSC Delivery Order";
        contact: Record Contact;
        posTrans: Record "LSC POS Transaction";
        storeT: Record "LSC Store";
        POSSESSION: Codeunit "LSC POS Session";
        retailUser: Record "LSC Retail User";
        lTxt1: Label 'No puede enviar el pedido a sucursal %1';
        lTxt2: Label 'Seleccione sucursal';
    begin
        RetailSetup.Get();
        if RetailSetup."FSN Is Local Receipt" then
            if (PosMenuLine.Command = 'DEL-TAKEORDFUNC') and (PosMenuLine.Parameter = 'ORDER-CLOSEPANEL') then begin

                if deliverOr.Get(POSSESSION.GetValue('CURRORDER')) then begin
                    if contact.Get(deliverOr."Phone No.") then begin
                        if not posTrans.Get(deliverOr."Order No.") then
                            exit;
                        retailUser.Get(UserId);
                        if (retailUser."Store No." = deliverOr."Restaurant No.") or
                            (retailUser."Store No." = posTrans."Store No.") then begin
                            Error(StrSubstNo(lTxt1, deliverOr."Restaurant No."));
                            exit;
                        end;

                        if posTrans."Customer No." = '' then
                            exit;
                    end;
                end else begin
                    retailUser.Get(UserId);
                    if (POSSESSION.GetValue('<#XLASTNEXTSTORE>') = retailUser."Store No.") or (POSSESSION.GetValue('<#XLASTNEXTSTORE>') = '') then begin
                        if storeT.Get(retailUser."Store No.") then
                            Error(StrSubstNo(lTxt1, storeT.Name))
                        else
                            Error(lTxt2);
                    end;
                    delo.PaymentPressed(0, 'PMT-PREPAID');
                end;
            end;
    end;

    /*[EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Transaction";
        var xRec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    var
        retailSetup: Record "LSC Retail Setup";
    begin
        if (Rec."Customer No." = '') then begin
            retailSetup.Get();
            if retailSetup."FSN Is Local Receipt" then
                Rec."Customer No." := GetCustomerID();
        end;

    end;*/



    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC POS Transaction";
        var xRec: Record "LSC POS Transaction";
        RunTrigger: Boolean
    )
    var
        retailSetup: Record "LSC Retail Setup";
        posLines: Record "LSC POS Trans. Line";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        DelOr: Record "LSC Delivery Order";
        Customer: Record Customer;
        MemberAcc: Record "LSC Member Account";
        MemberShip: Record "LSC Membership Card";
        MemberShipTem: Record "LSC Membership Card" temporary;
    begin
        /*if Rec."Sales Type" = '' then
            Rec."Sales Type" := 'DELIVERY';

        if (Rec."Currency Factor" = 0) and (Rec."Member Card No." <> '') then begin
            Rec."Currency Factor" := 1;
            xRec."Currency Factor" := 1;
        end;*/

        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        IF Processed THEN begin
            if (Rec."Sales Staff" <> xRec."Sales Staff") then begin
                xRec."Sales Staff" := Rec."Sales Staff";
                //xRec."Staff ID" := Rec."Staff ID";
            end else begin
                posLines.Reset();
                posLines.SetRange("Receipt No.", Rec."Receipt No.");
                posLines.SetRange("Entry Type", posLines."Entry Type"::Item);
                posLines.SetRange("Entry Status", posLines."Entry Status"::" ");
                if posLines.FindFirst() then begin
                    if NOT (posLines."Sales Staff" IN ['F20', '']) then begin
                        xRec."Sales Staff" := posLines."Sales Staff";
                        Rec."Sales Staff" := posLines."Sales Staff";
                    end;
                end;
            end;

            if (Rec."Customer No." = '') or (Rec."Customer Disc. Group" = '') then begin
                posLines.Reset();
                posLines.SetRange("Receipt No.", Rec."Receipt No.");
                posLines.SetRange("Entry Type", posLines."Entry Type"::FreeText);
                posLines.SetRange("Text Type", posLines."Text Type"::"Cust. Text");
                posLines.SetFilter(posLines."Card/Customer/Coup.Item No", '<>%1', '');
                if posLines.Find('-') then begin
                    xRec."Customer No." := posLines."Card/Customer/Coup.Item No";
                    Rec."Customer No." := posLines."Card/Customer/Coup.Item No";

                    retailSetup.Get();
                    if retailSetup."FSN Is Local Receipt" then begin
                        Customer.Reset();
                        if Customer.Get(posLines."Card/Customer/Coup.Item No") then begin
                            Rec."Customer Disc. Group" := Customer."Customer Disc. Group";
                            xRec."Customer Disc. Group" := Customer."Customer Disc. Group";
                        end;
                    end;
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC POS Transaction_OnBeforeInsertEvent"
(
    var Rec: Record "LSC POS Transaction";
    RunTrigger: Boolean
)
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        DelOr: Record "LSC Delivery Order";
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        IF Processed THEN begin
            Rec."Sales Staff" := POSSESSION.StaffID();
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Order", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "LSC Delivery Order_OnBeforeModifyEvent"
    (
        var Rec: Record "LSC Delivery Order";
        var xRec: Record "LSC Delivery Order";
        RunTrigger: Boolean
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        PosTransa: Record "LSC POS Transaction";
        DelConAdd: Record "LSC Delivery Contact Address";
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        IF Processed THEN begin
            IF PosTransa.Get(Rec."Order No.") then begin
                if (Rec."Order Taker" = '') or (xRec."Order Taker" = '') then begin
                    Rec."Order Taker" := PosTransa."Sales Staff";
                    xRec."Order Taker" := PosTransa."Sales Staff";
                end;
                IF Rec."Order Type Option" = 0 then begin
                    Rec."Order Type Option" := 1;
                    xRec."Order Type Option" := 1;
                end;

                if (Rec.Directions = '') or (xRec.Directions = '') then begin
                    if DelConAdd.Get(Rec."Phone No.", Rec."Order Type Option" - 1) then begin
                        Rec.Directions := DelConAdd.Directions;
                        xRec.Directions := DelConAdd.Directions;
                    end;
                end;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC Delivery Order", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "LSC Delivery Order_OnBeforeInsertEvent"
    (
        var Rec: Record "LSC Delivery Order";
        RunTrigger: Boolean
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
        PosTransa: Record "LSC POS Transaction";
    begin
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        IF Processed THEN begin
            IF PosTransa.Get(Rec."Order No.") then begin
                if (Rec."Order Taker" = '') then
                    Rec."Order Taker" := POSSESSION.StaffID();
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
            (
            var PosEvent: Codeunit "LSC POS Event";
            var SuppressEvent: Boolean
            )
    var
        SNum: Integer;
        DelOrdMag: Codeunit "LSC Delivery Order Management";
    begin
        if PosEvent.ActivePanel = '#POS' THEN begin
            POSSESSION.SetValue('VALCUSTOMERFSN', PosEvent.ActivePanel)
        end else
            POSSESSION.SetValue('VALCUSTOMERFSN', '');
    end;
    /*
        local procedure SetCustomerID(pCust: Code[20])
        begin
            CustomerCC := pCust;
        end;

        local procedure GetCustomerID(): Code[20]
        begin
            exit(CustomerCC);
        end;

        [EventSubscriber(ObjectType::Table, Database::"LSC POS Transaction", 'OnBeforeValidateEvent', 'Hosp. Type Sequence', true, true)]
        local procedure "LSC POS Transaction_OnBeforeValidateEvent_Hosp. Type Sequence"
        (
            var Rec: Record "LSC POS Transaction";
            var xRec: Record "LSC POS Transaction";
            CurrFieldNo: Integer
        )
        begin
            SetCustomerID(Rec."Customer No.");
        end;*/


    [EventSubscriber(ObjectType::Table, Database::"Contact", 'OnBeforeModifyEvent', '', true, true)]
    local procedure "Contact_OnBeforeModifyEvent"
    (
        var Rec: Record "Contact";
        var xRec: Record "Contact";
        RunTrigger: Boolean
    )
    var
        LastRecord: Record Contact;
    begin
        IF (Rec.Name = '') AND (xRec.Name = '') THEN begin
            if (LastRecord.Get(Rec."No.")) and (LastRecord.Name <> '') then begin
                Rec.Name := LastRecord.Name;
                xRec.Name := LastRecord.Name;
            end;
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Contact", 'OnBeforeInsertEvent', '', true, true)]
    local procedure "Contact_OnBeforeInsertEvent"
    (
        var Rec: Record "Contact";
        RunTrigger: Boolean
    )
    var
        POSSESSION: Codeunit "LSC POS Session";
        store_l: Record "LSC Store";
    begin

        if Rec.IsTemporary then
            if IsActive then
                SetStoreDelGlobals(Rec);

    end;

    [EventSubscriber(ObjectType::Table, Database::"Contact", 'OnAfterModifyEvent', '', true, true)]
    local procedure "Contact_OnAfterModifyEvent"
    (
        var Rec: Record "Contact";
        var xRec: Record "Contact";
        RunTrigger: Boolean
    )
    var
        POSSESSION: Codeunit "LSC POS Session";
        store_l: Record "LSC Store";
        Cont: Record "LSC Delivery Contact Address";
        DelCont: Record "LSC Delivery Contact Address";
    begin
        if Rec.IsTemporary then begin
            if IsActive then begin
                if (Rec."LSC Next Order Restaurant" = '') or
                (Rec."LSC Next Order Restaurant" = 'F20') then begin
                    DelCont.Reset();
                    DelCont.SetRange("Phone No.", Rec."No.");
                    DelCont.SetRange("Address Type", DelCont."Address Type"::Home);
                    if DelCont.FindFirst() then begin
                        Rec."LSC Next Order Restaurant" := DelCont."Restaurant No.";
                    end;
                end;
                SetStoreDelGlobals(Rec);
            end;
        end;
    end;

    local procedure SetStoreDelGlobals(var pRec: Record Contact)
    var
        POSSESSION: Codeunit "LSC POS Session";
        store_l: Record "LSC Store";
        UserRetail_l: Record "LSC Retail User";
        DelOrd_l: Record "LSC Delivery Order";
    begin
        clear(UserRetail_l);
        if UserRetail_l.Get(UserId) then;
        if pRec."LSC Next Order Restaurant" = UserRetail_l."Store No." then
            if DelOrd_l.Get(POSSESSION.GetValue('CURRORDER')) and (DelOrd_l."Order No." <> '') then
                pRec."LSC Next Order Restaurant" := DelOrd_l."Restaurant No.";

        POSSESSION.SetValue('<#XLASTNEXTSTORE>', pRec."LSC Next Order Restaurant");

        if store_l.Get(pRec."LSC Next Order Restaurant") then
            POSSESSION.SetValue('<#XLASTNEXTSTORENAME>', store_l.Name)
        else
            POSSESSION.SetValue('<#XLASTNEXTSTORENAME>', '');
    end;


    /*[EventSubscriber(ObjectType::Codeunit, 10012718, 'OnNumpadResult', '', false, false)]
    local procedure ProcessMyNumericKeyboard(payload: Text; inputValue: Text; resultOK: Boolean; var processed: Boolean)
    begin
    end;*/

    /*[EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnPOSEvent', '', true, true)]
    local procedure "LSC POS Controller_OnPOSEvent"
    (
        var PosEvent: Codeunit "LSC POS Event";
        var SuppressEvent: Boolean
    )
    begin
    end;*/
    /***********************************************************************************************************************/
    /* POS TRANSACCION */
    /***********************************************************************************************************************/
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterFinalizePosting', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterFinalizePosting"
    (
        var LastTransaction: Record "LSC Transaction Header";
        POSTransPostingStateTmp: Record "LSC POS Trans. Posting State"
    )
    begin
        PickUpWarning(LastTransaction);
    end;

    procedure PickUpWarning(TransHeader: Record "LSC Transaction Header")
    var
        BOUtils: Codeunit "LSC BO Utils";
        PickWarningText: Text[50];
        DescLen: Integer;
        WarnLen: Integer;
        CashMgm: Codeunit "LSC Cash Management";
        InfoTextDescription: Text;
        InfoTextDescription2: Text;
        Text290: Label 'PW';
    begin
        if not (BOUtils.IsHospitalityPermitted and (POSSESSION.GetValue('RESTAURANT') <> '')) then
            exit;

        PickWarningText := CalcPickUpWarning(TransHeader);
        if (PickWarningText = '') then
            exit;

        post.GetInfoTextDescription(InfoTextDescription, InfoTextDescription2);

        if (InfoTextDescription2 <> '') then begin
            DescLen := StrLen(InfoTextDescription);
            WarnLen := StrLen(PickWarningText);
            if ((DescLen + WarnLen + 2) < 80) then begin
                InfoTextDescription2 := InfoTextDescription2 + '. ' + PickWarningText;
            end
            else begin
                if ((DescLen + StrLen(Text290) + 2) < 80) then
                    InfoTextDescription2 := InfoTextDescription2 + '. ' + Text290;
            end;
        end
        else begin
            InfoTextDescription2 := PickWarningText;
        end;
        post.SetInfoTextDescription(InfoTextDescription, InfoTextDescription2);
    end;

    procedure CalcPickUpWarning(Trans: Record "LSC Transaction Header"): Text[50]
    var
        PayEntry: Record "LSC Trans. Payment Entry";
        PayEntry2: Record "LSC Trans. Payment Entry";
        TenderType: Record "LSC Tender Type";
        PosStartStat: Record "LSC POS Start Status";
        PosStartStat2: Record "LSC POS Start Status";
        PSS: Record "LSC POS Start Status";
        PickWarn: Record "LSC POS Pick Up Warning";
        TenderTypeCurrSetup: Record "LSC Tender Type Currency Setup";
        POSTerminal: Record "LSC POS Terminal";
        WarningAmount: Decimal;
        CompareAmount: Decimal;
        ErrorCode: Integer;
        ReturnText: Text[30];
        PickUpWarnTmp: Record "LSC POS Pick Up Warning" temporary;
        Text001: Label 'Make Pickup for Tender Type %1';
    begin
        //CalcPickUpWarning
        if Trans."Receipt No." = '' then
            exit;
        Store.Get(Trans."Store No.");
        POSTerminal.Get(Trans."POS Terminal No.");
        PosFuncProfile.Get(POSSESSION.FunctionalityProfileID);

        if not PosFuncProfile."POS Pickup Warning" then
            exit('');

        PickUpWarnTmp.Reset;
        PickUpWarnTmp.DeleteAll;

        Clear(PayEntry);
        PayEntry.SetRange("Store No.", Trans."Store No.");
        PayEntry.SetRange("POS Terminal No.", Trans."POS Terminal No.");
        PayEntry.SetRange("Transaction No.", Trans."Transaction No.");
        if PayEntry.FindFirst then begin
            PSS."Store No." := Trans."Store No.";
            if Store."Statement Method" = Store."Statement Method"::Staff then begin
                PickWarn.Type := PickWarn.Type::Staff;
                PickWarn.ID := Trans."Staff ID";
                PSS.Type := PSS.Type::Staff;
                PSS.ID := Trans."Staff ID";
            end
            else begin
                PickWarn.Type := PickWarn.Type::"POS Terminal";
                PickWarn.ID := Trans."POS Terminal No.";
                PSS.Type := PSS.Type::"POS Terminal";
                PSS.ID := Trans."POS Terminal No.";
            end;

            repeat
                WarningAmount := 0;
                if TenderType.Get(PayEntry."Store No.", PayEntry."Tender Type") then begin
                    ReturnText := TenderType."POS Pickup Warning Text";
                    if TenderType."Foreign Currency" then begin
                        if TenderTypeCurrSetup.Get(PayEntry."Store No.", TenderType.Code, PayEntry."Currency Code") then begin
                            WarningAmount := TenderTypeCurrSetup."POS Pickup Warning Amount";
                            if TenderTypeCurrSetup."POS Pickup Warning Text" <> '' then
                                ReturnText := TenderTypeCurrSetup."POS Pickup Warning Text";
                        end;
                    end
                    else
                        WarningAmount := TenderType."POS Pickup Warning Amount";
                end;

                if (WarningAmount <> 0) then begin
                    CompareAmount := 0;
                    if PickUpWarnTmp.Get(Trans."Store No.", PickWarn.Type, PickWarn.ID, PayEntry."Tender Type", PayEntry."Currency Code") then begin
                        PickUpWarnTmp.Amount := PickUpWarnTmp.Amount + PayEntry."Amount in Currency";
                        PickUpWarnTmp.Modify;
                        CompareAmount := PickUpWarnTmp.Amount;
                    end
                    else begin
                        //if Store."Statement Method" = Store."Statement Method"::Staff then begin
                        if false then begin

                        end else
                            //*****************************************
                            //* POS Terminal
                            //*****************************************
                            if Store."Safe Mgnt. in Use" then begin
                                if not PosStartStat.Get(PSS."Store No.", PSS.Type, PSS.ID) then begin
                                    InsertPosStartStatFromTrans(Trans);
                                    PosStartStat.Get(PSS."Store No.", PSS.Type, PSS.ID);
                                end;
                                Clear(PayEntry2);
                                PayEntry2.SetCurrentKey("Tender Decl. ID", "Tender Type", "Currency Code");
                                PayEntry2.SetRange("Tender Decl. ID", PosStartStat."Next Tender Decl. ID");
                                PayEntry2.SetRange("Tender Type", PayEntry."Tender Type");
                                PayEntry2.SetRange("Currency Code", PayEntry."Currency Code");
                                PayEntry2.SetRange("Store No.", PSS."Store No.");
                                PayEntry2.CalcSums("Amount in Currency");
                                CompareAmount := PayEntry2."Amount in Currency";
                            end
                            else begin
                                Clear(PayEntry2);
                                PayEntry2.SetCurrentKey("Tender Type", "Currency Code");
                                PayEntry2.SetRange("Tender Type", PayEntry."Tender Type");
                                PayEntry2.SetRange("Currency Code", PayEntry."Currency Code");
                                PayEntry2.SetRange("Store No.", PSS."Store No.");
                                PayEntry2.CalcSums("Amount in Currency");
                                CompareAmount := PayEntry2."Amount in Currency";
                            end;
                        Clear(PickUpWarnTmp);
                        PickUpWarnTmp."Store No." := PSS."Store No.";
                        PickUpWarnTmp.Type := PickWarn.Type;
                        PickUpWarnTmp.ID := PickWarn.ID;
                        PickUpWarnTmp."Tender Type" := PayEntry."Tender Type";
                        PickUpWarnTmp."Currency Code" := PayEntry."Currency Code";
                        PickUpWarnTmp.Amount := CompareAmount;
                        PickUpWarnTmp.Insert;
                    end;

                    if (CompareAmount > WarningAmount) then
                        if ReturnText <> '' then
                            exit(ReturnText)
                        else
                            exit(StrSubstNo(Text001, TenderType.Description));
                end;
            until PayEntry.Next = 0;
        end;

        exit('');
    end;

    local procedure InsertPosStartStatFromTrans(Trans: Record "LSC Transaction Header")
    var
        PosStartStat: Record "LSC POS Start Status";
        StoreRec: Record "LSC Store";
    begin
        //InsertPosStartStatFromTrans

        StoreRec.Get(Trans."Store No.");

        Clear(PosStartStat);
        PosStartStat."Store No." := Trans."Store No.";
        if StoreRec."Statement Method" = StoreRec."Statement Method"::Staff then begin
            PosStartStat.Type := PosStartStat.Type::Staff;
            PosStartStat.ID := Trans."Staff ID";
        end
        else begin
            PosStartStat.Type := PosStartStat.Type::"POS Terminal";
            PosStartStat.ID := Trans."POS Terminal No.";
        end;
        PosStartStat."Next Tender Decl. ID" := '0000000001';
        PosStartStat.Status := PosStartStat.Status::" ";
        PosStartStat.Date := Trans.Date;
        PosStartStat.Time := Trans.Time;
        PosStartStat."POS Terminal No." := Trans."POS Terminal No.";
        PosStartStat."Staff ID" := Trans."Staff ID";
        PosStartStat.Insert;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforeSelectCustPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforeSelectCustPressed"(var CustomerMandatory: Boolean)
    VAR
        POSFunction: Codeunit "LSC POS Functions";
    begin
        POSFunction.ClearmemberInfo();
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterRetSuspended', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterRetSuspended"(var POSTransaction: Record "LSC POS Transaction"; var POSTransLine: Record "LSC POS Trans. Line"; var CurrInput: Text)
    var
        posTransLine2: Record "LSC POS Trans. Line";
        posTransLine3: Record "LSC POS Trans. Line";
        fsnParameter: Record "FSN Parameter";
        item: Record "Item";
        customer: Record Customer;
        membership: Record "LSC Membership Card";
        schemeMebership: Record "LSC Member Scheme";
        menuLine: Record "LSC POS Menu Line";
        posTransC: Codeunit "LSC POS Transaction";
    begin
        if POSTransaction."Member Card No." <> '' then begin
            membership.Get(POSTransaction."Member Card No.");
            schemeMebership.Get(membership."Scheme Code");
            customer.Get(POSTransaction."Customer No.");
            if customer."LSC Retail Customer Group" <> 'COMODIN' then
                if (customer."Customer Disc. Group" <> schemeMebership."Default Cust. Disc. Group") and (schemeMebership."Default Cust. Disc. Group" <> '') then begin
                    customer."Customer Disc. Group" := schemeMebership."Default Cust. Disc. Group";
                    customer.Modify();
                end;
        end;

        if fsnParameter.Get('POS', 'BLOCKSCANN') and fsnParameter.Activo then begin
            posTransLine2.Reset();
            posTransLine2.SetRange("Receipt No.", POSTransaction."Receipt No.");
            posTransLine2.SetRange("Entry Status", posTransLine2."Entry Status"::" ");
            posTransLine2.SetRange("Entry Type", posTransLine2."Entry Type"::"Item");
            if posTransLine2.find('-') then
                repeat
                    posTransLine3 := posTransLine2;
                    if posTransLine3."Parent Line" <> 0 then
                        posTransLine3."Parent Line" := posTransLine2."Line No.";
                    posTransLine3."FSN Additional Action" := posTransLine3."FSN Additional Action"::ConfirmScann;
                    if item.Get(posTransLine2.Number) and (item."Purch. Unit of Measure" = posTransLine2."Unit of Measure") then
                        posTransLine3.Modify(true);
                until posTransLine2.next() = 0;
        end;
    end;


    local procedure DeletCustomerL(POSTransaction: Record "LSC POS Transaction")
    var
        myInt: Integer;
        POSTransLine: Record "LSC POS Trans. Line";
    begin
        POSTransLine.Reset();
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::FreeText);
        POSTransLine.SetFilter("Text Type", '=%1|%2', POSTransLine."Text Type"::"Cust. Text", POSTransLine."Text Type"::"Member Text");
        if POSTransLine.Find('-') then begin
            repeat
                if POSTransLine."Card/Customer/Coup.Item No" <> '' then
                    POSTransLine.Delete();
                Commit();
            until POSTransLine.Next() = 0;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Controller", 'OnButtonPressed', '', true, true)]
    local procedure "LSC POS Controller_OnButtonPressed"
    (
        var POSMenuLine: Record "LSC POS Menu Line";
        var handled: Boolean
    )
    var
        POSTransaction: Record "LSC POS Transaction";
        POSTransCodeunit: Codeunit "LSC POS Transaction";
        posLines, TransLine : Record "LSC POS Trans. Line";
        delOrder: Record "LSC Delivery Order";
        Customer_l: Record Customer;
        Customer2: Record Customer;
        Store_l: Record "LSC Store";
        PostCode_l: Record "Post Code";
        InfocodeEntry_l: Record "LSC POS Trans. Infocode Entry";
        DifAmount: Decimal;
    begin
        IF (POSMenuLine.Command = 'RUNOBJ') AND (POSMenuLine.Parameter = 'FSN CUST') then
            Commit();

        if NOT (POSMenuLine.Command = 'TOTAL') then
            EXIT;
        if not POSTransaction.Get(POSTransCodeunit.GetReceiptNo()) then
            exit;

        posLines.Reset();
        posLines.SetRange("Receipt No.", POSTransaction."Receipt No.");
        posLines.SetRange("Entry Status", posLines."Entry Status"::" ");
        posLines.SetRange("Entry Type", posLines."Entry Type"::Item);
        if posLines.find('-') then
            repeat
                posLines.CalcPrices();
                posLines.Modify();
            until posLines.Next() = 0;


        if Customer_l.get(POSTransaction."Customer No.") then begin
            Customer2 := Customer_l;


            PostCode_l.Reset();
            PostCode_l.SetRange(Code, Customer2."Post Code");
            if Customer2."Post Code" <> '' then
                if PostCode_l.Find('-') then begin
                    Customer2.County := PostCode_l.County;
                    Customer2.City := PostCode_l.City;
                end;

            if Customer2."Post Code" = '' then begin
                if Store_l.Get(POSTransaction."Store No.") then;
                Customer2.Validate("Post Code", Store_l."Post Code");
            end;

            if Customer2."DTE Tax ID Type" = 0 then
                case true of
                    (Customer2."FSN DUI" = '') and (Customer2."FSN NRC" <> ''):
                        Customer2."DTE Tax ID Type" := Customer2."DTE Tax ID Type"::NIT;
                    (Customer2."FSN DUI" <> ''):
                        Customer2."DTE Tax ID Type" := Customer2."DTE Tax ID Type"::DUI;
                    (Customer2."FSN Foreign document" <> ''):
                        Customer2."DTE Tax ID Type" := Customer2."DTE Tax ID Type"::Pasaporte;
                end;

            if delOrder.Get(POSTransaction."Receipt No.") then begin
                if Customer2.Address = '' then begin
                    Customer2.Address := CopyStr(delOrder.Directions, 1, 80);
                    Customer2."Address 2" := CopyStr(delOrder.Directions, 81, 50);
                    Customer2."FSN Address" := delOrder.Directions;
                end;
                if Customer2.Address = '' then begin
                    InfocodeEntry_l.Reset();
                    InfocodeEntry_l.SetRange("Receipt No.", POSTransaction."Receipt No.");
                    InfocodeEntry_l.SetRange(Infocode, 'DDIRECTION');
                    if InfocodeEntry_l.Find('-') then begin
                        Customer2.Address := CopyStr(InfocodeEntry_l.Information, 1, 80);
                        Customer2."Address 2" := CopyStr(InfocodeEntry_l.Information, 81, 20);
                        Customer2."FSN Address" := delOrder.Directions;
                    end;
                end;

                if Customer2."Phone No." = '' then
                    Customer2."Phone No." := delOrder."Phone No.";

            end;
            if Format(Customer2) <> Format(Customer_l) then
                Customer2.Modify(true);
        end;
    end;

    [EventSubscriber(ObjectType::Table, Database::"LSC POS Trans. Line", 'OnBeforeDeleteEvent', '', true, true)]
    local procedure "LSC POS Trans. Line_OnBeforeDeleteEvent"
    (
        var Rec: Record "LSC POS Trans. Line";
        RunTrigger: Boolean
    )
    begin
        if POSSession.FunctionalityProfileID = '' then
            POSSession.SetFunctionalityProfile('#FSN_CC');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnAfterTenderKeyPressed', '', true, true)]
    local procedure "LSC POS Transaction Events_OnAfterTenderKeyPressed"
    (
        var POSTransaction: Record "LSC POS Transaction";
        var POSTransLine: Record "LSC POS Trans. Line";
        var CurrInput: Text;
        var TenderTypeCode: Code[10]
    )
    var
        posT: Record "LSC POS Transaction";
    begin
        if posT.Get(POSTransaction."Receipt No.") then
            POSTransaction."Member Card No." := posT."Member Card No.";
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"LSC POS Transaction Events", 'OnBeforePosConfirm', '', true, true)]
    local procedure "LSC POS Transaction Events_OnBeforePosConfirm"
    (
        var POSTransaction: Record "LSC POS Transaction";
        Message: Text;
        var IsHandled: Boolean;
        var ReturnValue: Boolean
    )
    begin
        if StrPos(Message, '¿Confirmar cliente?') > 0 then begin
            IsHandled := true;
            ReturnValue := true;
        end;
    end;
}