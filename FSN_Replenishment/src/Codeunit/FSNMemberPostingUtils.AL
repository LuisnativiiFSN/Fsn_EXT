codeunit 50088 "FSN Member Posting Utils"
{
    Permissions = TableData "Sales Invoice Line" = m,
                  TableData "Sales Cr.Memo Line" = m;
    TableNo = "LSC Scheduler Job Header";
    trigger OnRun()
    var
        ProcessOrderEntry: Record "LSC Member Process Order Entry";
        TransHeader: Record "LSC Transaction Header";
        Window: Dialog;
        NoOfTrans: Integer;
        NoOfUnsuccessful: Integer;
        fromDate: Date;
        toDate: Date;
        AccountRec: Record "LSC Member Account";
        Text000: label 'Numero de cuenta %1 no existe en tabla LSC Member Account';
    begin

        if GuiAllowed then
            Window.Open('#1############################################################');

        ProcessOrderEntry.SetCurrentKey("Date Processed");
        ProcessOrderEntry.SetRange("Date Processed", 0D);
        if Rec.Code <> '' then
            ProcessOrderEntry.SetRange(ProcessOrderEntry."Account No.", Rec.Code)
        else
            if Rec.Date <> 0D then
                ProcessOrderEntry.SetRange(ProcessOrderEntry.Date, Rec.Date)
            else
                ProcessOrderEntry.Setfilter(ProcessOrderEntry.Date, '>=%1&<=%2', TODAY - 3, TODAY - 2);
        if ProcessOrderEntry.FindSet then
            repeat
                if AccountRec.get(ProcessOrderEntry."Account No.") then begin
                    NoOfTrans := NoOfTrans + 1;
                    if GuiAllowed then
                        Window.Update(1, StrSubstNo(Text001, ProcessOrderEntry."Document Source", ProcessOrderEntry."Document No."));
                    if ProcessOrderEntry."Document Source" = ProcessOrderEntry."Document Source"::POS then
                        if TransHeader.Get(ProcessOrderEntry."Store No.", ProcessOrderEntry."POS Terminal No.", ProcessOrderEntry."Transaction No.") then begin
                            if not UpdateMemberFromPOS(TransHeader) then
                                NoOfUnsuccessful := NoOfUnsuccessful + 1;
                        end else begin
                            ProcessOrderEntry.Message := StrSubstNo(Text007, TransHeader.TableCaption);
                            ProcessOrderEntry.Modify;
                        end;
                end else begin
                    ProcessOrderEntry.Message := StrSubstNo(Text000, ProcessOrderEntry."Account No.");
                    ProcessOrderEntry.Modify;
                end;
            until ProcessOrderEntry.Next = 0;
        if GuiAllowed then begin
            Window.Close;
            Message(Text002, NoOfTrans - NoOfUnsuccessful, NoOfTrans);
        end;
    end;

    var
        Text001: Label 'Updating Member Information from %1 %2';
        Text002: Label '%1 of %2 document(s) processed.';
        Text003: Label '%1 already processed but was not marked as processed.';
        Text004: Label 'Card not linked to an Account. %1 not processed.';
        Text007: Label '%1 not found.';
        Text008: Label 'Sum of points in %1 = %2 does not match %3.';
        Text009: Label '%1 data missing.';
        Text010: Label 'The Balance for the Account went negative with this transaction';
        Text011: Label 'No %1 in %2.';
        Text012: Label '%1 %2 not found.';
        LocalizationExt: Codeunit "LSC Retail Localization Ext.";

    [Scope('OnPrem')]
    procedure CheckTransactionDataOk(TransHeader_p: Record "LSC Transaction Header"; var ProcessOrderEntry_p: Record "LSC Member Process Order Entry"): Boolean
    var
        MemberCard_l: Record "LSC Membership Card";
        MemberCardManagement_l: Codeunit "LSC Member Card Management";
        MessageText_l: Text;
        IsHandled: Boolean;
        ReturnValue: Boolean;
    begin
        OnBeforeCheckTransactionDataOk(TransHeader_p, ProcessOrderEntry_p, IsHandled, ReturnValue);
        if IsHandled then
            exit(ReturnValue);
        if not PointMatchWithEntries(ProcessOrderEntry_p) then
            exit(false);
        if not TransSalesEntriesOk(ProcessOrderEntry_p) then
            exit(false);
        if not TransDiscountEntiresOk(ProcessOrderEntry_p) then
            exit(false);
        if TransHeader_p."Member Card No." = '' then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text011, TransHeader_p.FieldCaption("Member Card No."), TransHeader_p.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(false);
        end;
        if not MemberCard_l.Get(TransHeader_p."Member Card No.") then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text012, MemberCard_l.TableCaption, TransHeader_p.FieldCaption("Member Card No."));
            ProcessOrderEntry_p.Modify;
            exit(false);
        end;
        if not MemberCardManagement_l.ValidateCard(MemberCard_l, MessageText_l) then begin
            ProcessOrderEntry_p.Message := MessageText_l;
            ProcessOrderEntry_p.Modify;
            exit(false);
        end;
        if MemberCard_l."Contact No." = '' then begin
            //Card not linked to an Account. Will be processed after it is linked.
            ProcessOrderEntry_p.Message := StrSubstNo(Text004, ProcessOrderEntry_p.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(false);
        end;
        exit(true);
    end;

    [Scope('OnPrem')]
    procedure UpdateMemberFromPOS(TransHeader: Record "LSC Transaction Header"): Boolean
    var
        MemberCard: Record "LSC Membership Card";
        ProcessOrderEntry: Record "LSC Member Process Order Entry";
        TransDiscEntry: Record "LSC Trans. Discount Entry";
        TransPointEntry: Record "LSC Trans. Point Entry";
        MemberAttributeEntry: Record "LSC Member Attribute Entry";
        DiscTrackingEntry: Record "LSC Discount Tracking Entry";
        POSCalcMemberPoints_l: Codeunit "LSC POS Calc. Member Points";
        TransID: Integer;
        AwardPoints: Decimal;
        OtherPoints: Decimal;
    begin
        if TransHeader."Member Card No." = '' then
            exit;
        if not MemberCard.Get(TransHeader."Member Card No.") then
            exit;
        if not ProcessOrderEntry.Get(ProcessOrderEntry."Document Source"::POS, TransHeader."Store No.", TransHeader."POS Terminal No.", TransHeader."Transaction No.") then
            POSCalcMemberPoints_l.CreateProcessOrderEntry(TransHeader, MemberCard."Account No.", ProcessOrderEntry);
        if not CheckTransactionDataOk(TransHeader, ProcessOrderEntry) then
            exit;
        ProcessOrderEntry."Date Processed" := Today;
        ProcessOrderEntry."Time Processed" := Time;
        ProcessOrderEntry.Message := '';
        if (TransHeader."Starting Point Balance" > 0) and (TransHeader."Starting Point Balance" + ProcessOrderEntry."Points in Transaction" < 0) then
            ProcessOrderEntry.Message := Text010;
        ProcessOrderEntry.Modify;
        if TransactionAlreadyProcessed(TransHeader, ProcessOrderEntry) then
            exit;
        if ProcessOrderEntry."Account No." = '' then begin
            ProcessOrderEntry.Message := '';
            ProcessOrderEntry."Account No." := MemberCard."Account No.";
            ProcessOrderEntry.Modify;
        end;
        TransID := AddMemberSalesEntryFromTransHeader(TransHeader, AwardPoints, OtherPoints);
        TransDiscEntry.SetRange("Store No.", TransHeader."Store No.");
        TransDiscEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransDiscEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        if TransDiscEntry.FindSet then
            repeat
                if TransDiscEntry."Member Attribute" <> '' then
                    if MemberAttributeEntry.Get(TransID, TransDiscEntry."Member Attribute", TransDiscEntry."Member Attribute Value") then begin
                        MemberAttributeEntry."Discount Amount" := MemberAttributeEntry."Discount Amount" + TransDiscEntry."Discount Amount";
                        MemberAttributeEntry.Points := MemberAttributeEntry.Points + TransDiscEntry.Points;
                        MemberAttributeEntry.Modify;
                    end else begin
                        MemberAttributeEntry.Init;
                        MemberAttributeEntry."Entry No." := TransID;
                        MemberAttributeEntry."Attribute ID" := TransDiscEntry."Member Attribute";
                        MemberAttributeEntry."Attribute Value" := TransDiscEntry."Member Attribute Value";
                        MemberAttributeEntry."Source Type" := MemberAttributeEntry."Source Type"::"POS Transaction";
                        MemberAttributeEntry."Document No." := TransHeader."Receipt No.";
                        MemberAttributeEntry."Member Account No." := MemberCard."Account No.";
                        MemberAttributeEntry."Club Code" := MemberCard."Club Code";
                        MemberAttributeEntry."Scheme Code" := MemberCard."Scheme Code";
                        MemberAttributeEntry."Member Contact No." := MemberCard."Contact No.";
                        MemberAttributeEntry."Discount Amount" := TransDiscEntry."Discount Amount";
                        MemberAttributeEntry.Points := TransDiscEntry.Points;
                        MemberAttributeEntry.Date := TransHeader.Date;
                        MemberAttributeEntry."Store No." := TransHeader."Store No.";
                        MemberAttributeEntry."POS Terminal No." := TransHeader."POS Terminal No.";
                        MemberAttributeEntry."Transaction No." := TransHeader."Transaction No.";
                        MemberAttributeEntry.Insert;
                    end;

                if TransDiscEntry."Tracking No." <> '' then
                    if DiscTrackingEntry.Get(TransID, TransDiscEntry."Tracking No.") then begin
                        DiscTrackingEntry."Discount Amount" := DiscTrackingEntry."Discount Amount" + TransDiscEntry."Discount Amount";
                        DiscTrackingEntry.Points := DiscTrackingEntry.Points + TransDiscEntry.Points;
                        DiscTrackingEntry."No. of Times" := DiscTrackingEntry."No. of Times" + 1;
                        DiscTrackingEntry.Modify;
                    end else begin
                        DiscTrackingEntry.Init;
                        DiscTrackingEntry."Entry No." := TransID;
                        DiscTrackingEntry."Tracking No." := TransDiscEntry."Tracking No.";
                        DiscTrackingEntry.Date := TransHeader.Date;
                        DiscTrackingEntry."Discount Amount" := TransDiscEntry."Discount Amount";
                        DiscTrackingEntry.Points := TransDiscEntry.Points;
                        DiscTrackingEntry."No. of Times" := 1;
                        DiscTrackingEntry."Store No." := TransHeader."Store No.";
                        DiscTrackingEntry."POS Terminal No." := TransHeader."POS Terminal No.";
                        DiscTrackingEntry."Transaction No." := TransHeader."Transaction No.";
                        DiscTrackingEntry."Document Type" := DiscTrackingEntry."Document Type"::"POS Transaction";
                        DiscTrackingEntry."Document No." := TransHeader."Receipt No.";
                        DiscTrackingEntry."Club Code" := MemberCard."Club Code";
                        DiscTrackingEntry."Scheme Code" := MemberCard."Scheme Code";
                        DiscTrackingEntry."Account No." := MemberCard."Account No.";
                        DiscTrackingEntry."Contact No." := MemberCard."Contact No.";
                        DiscTrackingEntry."Card No." := MemberCard."Card No.";
                        DiscTrackingEntry.Insert;
                    end;
            until TransDiscEntry.Next = 0;

        TransPointEntry.SetRange("Store No.", TransHeader."Store No.");
        TransPointEntry.SetRange("POS Terminal No.", TransHeader."POS Terminal No.");
        TransPointEntry.SetRange("Transaction No.", TransHeader."Transaction No.");
        TransPointEntry.SetRange("Entry Type", TransPointEntry."Entry Type"::Payment);
        if TransPointEntry.FindSet then
            repeat
                AddMemberPointEntryPOS(-TransPointEntry.Points, true, true, TransHeader);
            until TransPointEntry.Next = 0;

        TransPointEntry.SetRange("Entry Type", TransPointEntry."Entry Type"::Sale);
        TransPointEntry.SetFilter("Disc. Benefit Points", '<>%1', 0);
        if TransPointEntry.FindSet then
            repeat
                if TransPointEntry."Point Type" = TransPointEntry."Point Type"::Award then
                    AwardPoints := AwardPoints + TransPointEntry."Disc. Benefit Points"
                else
                    OtherPoints := OtherPoints + TransPointEntry."Disc. Benefit Points";
            until TransPointEntry.Next = 0;

        TransPointEntry.SetRange("Disc. Benefit Points");
        TransPointEntry.SetFilter("Tender Points", '<>%1', 0);
        if TransPointEntry.FindSet then
            repeat
                if TransPointEntry."Point Type" = TransPointEntry."Point Type"::Award then
                    AwardPoints := AwardPoints + TransPointEntry."Tender Points"
                else
                    OtherPoints := OtherPoints + TransPointEntry."Tender Points";
            until TransPointEntry.Next = 0;
        AddMemberPointEntryPOS(AwardPoints, true, false, TransHeader);
        AddMemberPointEntryPOS(OtherPoints, false, false, TransHeader);
        exit(true);
    end;

    [Scope('OnPrem')]
    procedure RoundPoints(pPoints: Decimal; Club: Record "LSC Member Club"): Decimal
    var
        Direction: Text[1];
    begin
        case Club."Point Rounding Type" of
            Club."Point Rounding Type"::Down:
                Direction := '<';
            Club."Point Rounding Type"::Nearest:
                Direction := '=';
            Club."Point Rounding Type"::Up:
                Direction := '>';
        end;

        if Club."Point Rounding Precision" <> 0 then
            exit(Round(pPoints, Club."Point Rounding Precision", Direction))
        else
            exit(Round(pPoints, 0.01, Direction));
    end;

    [Scope('OnPrem')]
    procedure TransactionAlreadyProcessed(TransactionHeader_p: Record "LSC Transaction Header"; var ProcessOrderEntry_p: Record "LSC Member Process Order Entry"): Boolean
    var
        MemberPointEntry_l: Record "LSC Member Point Entry";
        MemberSalesEntry_l: Record "LSC Member Sales Entry";
        MemberAttributeEntry_l: Record "LSC Member Attribute Entry";
        DiscountTrackingEntry_l: Record "LSC Discount Tracking Entry";
    begin
        MemberPointEntry_l.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        MemberPointEntry_l.SetRange("Store No.", TransactionHeader_p."Store No.");
        MemberPointEntry_l.SetRange("POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        MemberPointEntry_l.SetRange("Transaction No.", TransactionHeader_p."Transaction No.");
        if MemberPointEntry_l.FindFirst then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text003, MemberPointEntry_l.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(true);
        end;

        MemberSalesEntry_l.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        MemberSalesEntry_l.SetRange("Store No.", TransactionHeader_p."Store No.");
        MemberSalesEntry_l.SetRange("POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        MemberSalesEntry_l.SetRange("Transaction No.", TransactionHeader_p."Transaction No.");
        if MemberSalesEntry_l.FindFirst then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text003, MemberSalesEntry_l.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(true);
        end;

        MemberAttributeEntry_l.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        MemberAttributeEntry_l.SetRange("Store No.", TransactionHeader_p."Store No.");
        MemberAttributeEntry_l.SetRange("POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        MemberAttributeEntry_l.SetRange("Transaction No.", TransactionHeader_p."Transaction No.");
        if MemberAttributeEntry_l.FindFirst then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text003, MemberAttributeEntry_l.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(true);
        end;

        DiscountTrackingEntry_l.SetCurrentKey("Store No.", "POS Terminal No.", "Transaction No.");
        DiscountTrackingEntry_l.SetRange("Store No.", TransactionHeader_p."Store No.");
        DiscountTrackingEntry_l.SetRange("POS Terminal No.", TransactionHeader_p."POS Terminal No.");
        DiscountTrackingEntry_l.SetRange("Transaction No.", TransactionHeader_p."Transaction No.");
        if DiscountTrackingEntry_l.FindFirst then begin
            ProcessOrderEntry_p.Message := StrSubstNo(Text003, DiscountTrackingEntry_l.TableCaption);
            ProcessOrderEntry_p.Modify;
            exit(true);
        end;

        exit(false);
    end;

    [Scope('OnPrem')]
    procedure PointMatchWithEntries(var ProcessOrderEntry_p: Record "LSC Member Process Order Entry"): Boolean
    var
        TransPointEntry_l: Record "LSC Trans. Point Entry";
        Points_l: Decimal;
    begin
        Points_l := 0;
        TransPointEntry_l.SetRange("Store No.", ProcessOrderEntry_p."Store No.");
        TransPointEntry_l.SetRange("POS Terminal No.", ProcessOrderEntry_p."POS Terminal No.");
        TransPointEntry_l.SetRange("Transaction No.", ProcessOrderEntry_p."Transaction No.");
        if TransPointEntry_l.FindSet then
            repeat
                Points_l := Points_l + TransPointEntry_l.Points;
            until TransPointEntry_l.Next = 0;
        if Points_l = ProcessOrderEntry_p."Points in Transaction" then
            exit(true);

        ProcessOrderEntry_p.Message := StrSubstNo(Text008, TransPointEntry_l.TableCaption, Points_l, ProcessOrderEntry_p.FieldCaption("Points in Transaction"));
        ProcessOrderEntry_p.Modify;
        exit(false);
    end;

    [Scope('OnPrem')]
    procedure TransSalesEntriesOk(var ProcessOrderEntry_p: Record "LSC Member Process Order Entry"): Boolean
    var
        TransSalesEntry_l: Record "LSC Trans. Sales Entry";
    begin
        TransSalesEntry_l.SetRange("Store No.", ProcessOrderEntry_p."Store No.");
        TransSalesEntry_l.SetRange("POS Terminal No.", ProcessOrderEntry_p."POS Terminal No.");
        TransSalesEntry_l.SetRange("Transaction No.", ProcessOrderEntry_p."Transaction No.");
        if TransSalesEntry_l.Count = ProcessOrderEntry_p."Trans Sales Entries" then
            exit(true);

        ProcessOrderEntry_p.Message := StrSubstNo(Text009, TransSalesEntry_l.TableCaption);
        ProcessOrderEntry_p.Modify;
        exit(false);
    end;

    [Scope('OnPrem')]
    procedure TransDiscountEntiresOk(var ProcessOrderEntry_p: Record "LSC Member Process Order Entry"): Boolean
    var
        TransDiscountEntry_l: Record "LSC Trans. Discount Entry";
    begin
        TransDiscountEntry_l.SetRange("Store No.", ProcessOrderEntry_p."Store No.");
        TransDiscountEntry_l.SetRange("POS Terminal No.", ProcessOrderEntry_p."POS Terminal No.");
        TransDiscountEntry_l.SetRange("Transaction No.", ProcessOrderEntry_p."Transaction No.");
        if TransDiscountEntry_l.Count = ProcessOrderEntry_p."Trans Discount Entries" then
            exit(true);

        ProcessOrderEntry_p.Message := StrSubstNo(Text009, TransDiscountEntry_l.TableCaption);
        ProcessOrderEntry_p.Modify;
        exit(false);
    end;

    [Scope('OnPrem')]
    procedure AddMemberSalesEntryFromTransHeader(TransHeader_p: Record "LSC Transaction Header"; var AwardPoints_p: Decimal; var OtherPoints_p: Decimal): Integer
    var
        MemberCard_l: Record "LSC Membership Card";
        MemberSalesEntry_l: Record "LSC Member Sales Entry";
        TransSalesEntry_l: Record "LSC Trans. Sales Entry";
        TransID_l: Integer;
        FBPUtility_l: Codeunit "LSC FBP Utility";
        Item: Record Item;
    begin
        MemberCard_l.Get(TransHeader_p."Member Card No.");
        TransID_l := NextTransID;

        TransSalesEntry_l.SetRange("Store No.", TransHeader_p."Store No.");
        TransSalesEntry_l.SetRange("POS Terminal No.", TransHeader_p."POS Terminal No.");
        TransSalesEntry_l.SetRange("Transaction No.", TransHeader_p."Transaction No.");
        if TransSalesEntry_l.FindSet then
            repeat
                MemberSalesEntry_l.Init;
                MemberSalesEntry_l."Entry No." := TransID_l;
                MemberSalesEntry_l."Line No." := TransSalesEntry_l."Line No.";
                MemberSalesEntry_l."Source Type" := MemberSalesEntry_l."Source Type"::"POS Transaction";
                MemberSalesEntry_l."Document No." := TransSalesEntry_l."Receipt No.";
                MemberSalesEntry_l."Member Account No." := MemberCard_l."Account No.";
                MemberSalesEntry_l."Member Contact No." := MemberCard_l."Contact No.";
                MemberSalesEntry_l."Member Card No." := TransHeader_p."Member Card No.";
                MemberSalesEntry_l."Member Club" := MemberCard_l."Club Code";
                MemberSalesEntry_l."Member Scheme" := MemberCard_l."Scheme Code";
                MemberSalesEntry_l.Quantity := TransSalesEntry_l.Quantity;
                MemberSalesEntry_l."Net Amount" := TransSalesEntry_l."Net Amount";
                MemberSalesEntry_l."Gross Amount" := TransSalesEntry_l."Net Amount" + TransSalesEntry_l."VAT Amount";
                MemberSalesEntry_l."Discount Amount" := TransSalesEntry_l."Discount Amount";
                MemberSalesEntry_l."Cost Amount" := TransSalesEntry_l."Cost Amount";
                MemberSalesEntry_l."Points Type" := TransSalesEntry_l."Member Points Type";
                MemberSalesEntry_l.Points := TransSalesEntry_l."Member Points";
                MemberSalesEntry_l.Date := TransSalesEntry_l.Date;
                MemberSalesEntry_l."Item No." := TransSalesEntry_l."Item No.";
                MemberSalesEntry_l."Item Variant Code" := TransSalesEntry_l."Variant Code";
                MemberSalesEntry_l."Item Category Code" := TransSalesEntry_l."Item Category Code";
                MemberSalesEntry_l."Retail Product Code" := TransSalesEntry_l."Retail Product Code";
                MemberSalesEntry_l."Store No." := TransSalesEntry_l."Store No.";
                MemberSalesEntry_l."POS Terminal No." := TransSalesEntry_l."POS Terminal No.";
                MemberSalesEntry_l."Transaction No." := TransSalesEntry_l."Transaction No.";
                Item.Init;
                if Item.Get(TransSalesEntry_l."Item No.") then
                    MemberSalesEntry_l.Description := Item.Description;
                if MemberSalesEntry_l.Insert(true) then;

                OnAfterInsertMemberSalesEntryFromTransHeader(TransSalesEntry_l, MemberCard_l, MemberSalesEntry_l);

                if MemberSalesEntry_l."Points Type" = MemberSalesEntry_l."Points Type"::"Award Points" then
                    AwardPoints_p := AwardPoints_p + MemberSalesEntry_l.Points
                else
                    OtherPoints_p := OtherPoints_p + MemberSalesEntry_l.Points;

                FBPUtility_l.ProcessMemberSalesEntry(MemberSalesEntry_l);
            until TransSalesEntry_l.Next = 0;
        exit(TransID_l);
    end;

    [Scope('OnPrem')]
    procedure UpdateMemberFromSalesInvoice(SalesInvoiceHeader_p: Record "Sales Invoice Header")
    var
        SalesInvoiceLine_l: Record "Sales Invoice Line";
        BOUtils_l: Codeunit "LSC BO Utils";
        MemberPointEntry_l: Record "LSC Member Point Entry";
        MemberCard_l: Record "LSC Membership Card";
        MemberManagementSetup_l: Record "LSC Member Management Setup";
        MemberPointSetup_l: Record "LSC Member Point Setup";
        MemberCardManagement_l: Codeunit "LSC Member Card Management";
        PosCalcMemberPoints_l: Codeunit "LSC POS Calc. Member Points";
        MessageText_l: Text;
        AmountBase_l: Decimal;
        ItemPoints_l: Decimal;
        AwardPoints_l: Decimal;
        OtherPoints_l: Decimal;
        CurrencyFactor_l: Decimal;
    begin
        if SalesInvoiceHeader_p."LSC Member Card No." = '' then
            exit;
        if not LocalizationExt.IsNALocalizationEnabled then
            if not BOUtils_l.IsInStorePermitted then
                exit;
        MemberCard_l.Get(SalesInvoiceHeader_p."LSC Member Card No.");
        if not MemberCardManagement_l.ValidateCard(MemberCard_l, MessageText_l) then
            Error(MessageText_l);
        MemberPointEntry_l.Reset;
        MemberPointEntry_l.SetRange("Source Type", MemberPointEntry_l."Source Type"::"Sales Invoice");
        MemberPointEntry_l.SetRange("Document No.", SalesInvoiceHeader_p."No.");
        if MemberPointEntry_l.FindFirst then
            exit; //Already processed.

        if not MemberManagementSetup_l.FindFirst then
            Clear(MemberManagementSetup_l);

        if SalesInvoiceHeader_p."Currency Code" <> '' then
            CurrencyFactor_l := SalesInvoiceHeader_p."Currency Factor"
        else
            CurrencyFactor_l := 1;

        SalesInvoiceLine_l.Reset;
        SalesInvoiceLine_l.SetRange("Document No.", SalesInvoiceHeader_p."No.");
        SalesInvoiceLine_l.SetRange(Type, SalesInvoiceLine_l.Type::Item);
        SalesInvoiceLine_l.SetFilter(Quantity, '<>%1', 0);
        if SalesInvoiceLine_l.FindSet then
            repeat
                if PosCalcMemberPoints_l.CalcPoints(SalesInvoiceHeader_p."Currency Code", SalesInvoiceLine_l."Posting Date", SalesInvoiceLine_l."Item Category Code",
                  SalesInvoiceLine_l."LSC Retail Product Code", SalesInvoiceLine_l."No.", MemberCard_l, FindActivePriceGroup(MemberCard_l), MemberPointSetup_l)
                then begin
                    if MemberManagementSetup_l."Amount Type for Point Calc." = MemberManagementSetup_l."Amount Type for Point Calc."::"Gross Amount" then
                        AmountBase_l := SalesInvoiceLine_l."Amount Including VAT" / CurrencyFactor_l
                    else
                        AmountBase_l := SalesInvoiceLine_l.Amount / CurrencyFactor_l;

                    if MemberPointSetup_l."Base Calculation on" = MemberPointSetup_l."Base Calculation on"::Amount then
                        ItemPoints_l := Round(AmountBase_l * MemberPointSetup_l.Points / MemberPointSetup_l."Unit Rate", 0.01)
                    else
                        ItemPoints_l := Round(SalesInvoiceLine_l.Quantity * MemberPointSetup_l.Points / MemberPointSetup_l."Unit Rate", 0.01);
                end;

                if ItemPoints_l <> 0 then begin
                    if MemberPointSetup_l."Points Type" = MemberPointSetup_l."Points Type"::"Award Points" then begin
                        AwardPoints_l := AwardPoints_l + ItemPoints_l;
                        SalesInvoiceLine_l."LSC Member Points Type" := SalesInvoiceLine_l."LSC Member Points Type"::"Award Points";
                    end else begin
                        OtherPoints_l := OtherPoints_l + ItemPoints_l;
                        SalesInvoiceLine_l."LSC Member Points Type" := SalesInvoiceLine_l."LSC Member Points Type"::"Other Points";
                    end;
                    SalesInvoiceLine_l."LSC Member Points" := ItemPoints_l;
                    SalesInvoiceLine_l.Modify;
                end;

            until SalesInvoiceLine_l.Next = 0;

        AddMemberPointEntry(AwardPoints_l, true, true, SalesInvoiceHeader_p."No.", SalesInvoiceHeader_p."LSC Store No.",
          SalesInvoiceHeader_p."Posting Date", MemberCard_l);
        AddMemberPointEntry(OtherPoints_l, false, true, SalesInvoiceHeader_p."No.", SalesInvoiceHeader_p."LSC Store No.",
          SalesInvoiceHeader_p."Posting Date", MemberCard_l);

        AddMemberSalesEntryFromSalesInvoice(SalesInvoiceHeader_p);
    end;

    [Scope('OnPrem')]
    procedure AddMemberSalesEntryFromSalesInvoice(SalesInvoiceHeader_p: Record "Sales Invoice Header")
    var
        MemberSalesEntry_l: Record "LSC Member Sales Entry";
        SalesInvoiceLine_l: Record "Sales Invoice Line";
        MemberCard_l: Record "LSC Membership Card";
        TransID_l: Integer;
        CurrencyFactor_l: Decimal;
        FBPUtility_l: Codeunit "LSC FBP Utility";
    begin
        MemberCard_l.Get(SalesInvoiceHeader_p."LSC Member Card No.");
        TransID_l := NextTransID;

        if SalesInvoiceHeader_p."Currency Code" <> '' then
            CurrencyFactor_l := SalesInvoiceHeader_p."Currency Factor"
        else
            CurrencyFactor_l := 1;

        SalesInvoiceLine_l.Reset;
        SalesInvoiceLine_l.SetRange("Document No.", SalesInvoiceHeader_p."No.");
        SalesInvoiceLine_l.SetFilter(Amount, '<>%1', 0);
        if SalesInvoiceLine_l.FindSet then
            repeat
                MemberSalesEntry_l.Init;
                MemberSalesEntry_l."Entry No." := TransID_l;
                MemberSalesEntry_l."Line No." := SalesInvoiceLine_l."Line No.";
                MemberSalesEntry_l."Source Type" := MemberSalesEntry_l."Source Type"::"Sales Invoice";
                MemberSalesEntry_l."Document No." := SalesInvoiceLine_l."Document No.";
                MemberSalesEntry_l."Member Account No." := MemberCard_l."Account No.";
                MemberSalesEntry_l."Member Contact No." := MemberCard_l."Contact No.";
                MemberSalesEntry_l."Member Card No." := SalesInvoiceHeader_p."LSC Member Card No.";
                MemberSalesEntry_l."Member Club" := MemberCard_l."Club Code";
                MemberSalesEntry_l."Member Scheme" := MemberCard_l."Scheme Code";
                MemberSalesEntry_l.Quantity := -SalesInvoiceLine_l.Quantity;
                MemberSalesEntry_l."Net Amount" := -SalesInvoiceLine_l.Amount / CurrencyFactor_l;
                MemberSalesEntry_l."Gross Amount" := -SalesInvoiceLine_l."Amount Including VAT" / CurrencyFactor_l;
                MemberSalesEntry_l."Discount Amount" := SalesInvoiceLine_l."Line Discount Amount" / CurrencyFactor_l;
                MemberSalesEntry_l."Cost Amount" := -SalesInvoiceLine_l."Unit Cost (LCY)" * SalesInvoiceLine_l.Quantity;
                MemberSalesEntry_l."Points Type" := SalesInvoiceLine_l."LSC Member Points Type";
                MemberSalesEntry_l.Points := SalesInvoiceLine_l."LSC Member Points";
                MemberSalesEntry_l.Date := SalesInvoiceHeader_p."Posting Date";
                MemberSalesEntry_l."Item No." := SalesInvoiceLine_l."No.";
                MemberSalesEntry_l."Item Variant Code" := SalesInvoiceLine_l."Variant Code";
                MemberSalesEntry_l."Item Category Code" := SalesInvoiceLine_l."Item Category Code";
                MemberSalesEntry_l."Retail Product Code" := SalesInvoiceLine_l."LSC Retail Product Code";
                MemberSalesEntry_l."Store No." := SalesInvoiceHeader_p."LSC Store No.";
                MemberSalesEntry_l.Description := SalesInvoiceLine_l.Description;
                if MemberSalesEntry_l.Insert(true) then;

                OnAfterInsertMemberSalesEntryFromSalesInvoice(SalesInvoiceHeader_p, SalesInvoiceLine_l, MemberCard_l, MemberSalesEntry_l);

                FBPUtility_l.ProcessMemberSalesEntry(MemberSalesEntry_l);
            until SalesInvoiceLine_l.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure UpdateMemberFromCrMemo(SalesCrMemoHeader_p: Record "Sales Cr.Memo Header")
    var
        SalesCrMemoLine_l: Record "Sales Cr.Memo Line";
        BOUtils_l: Codeunit "LSC BO Utils";
        MemberPointEntry_l: Record "LSC Member Point Entry";
        MemberCard_l: Record "LSC Membership Card";
        MemberManagementSetup_l: Record "LSC Member Management Setup";
        MemberPointSetup_l: Record "LSC Member Point Setup";
        MemberCardManagement_l: Codeunit "LSC Member Card Management";
        PosCalcMemberPoints_l: Codeunit "LSC POS Calc. Member Points";
        MessageText_l: Text;
        AmountBase_l: Decimal;
        ItemPoints_l: Decimal;
        AwardPoints_l: Decimal;
        OtherPoints_l: Decimal;
        CurrencyFactor_l: Decimal;
    begin
        if SalesCrMemoHeader_p."LSC Member Card No." = '' then
            exit;
        if not LocalizationExt.IsNALocalizationEnabled then
            if not BOUtils_l.IsInStorePermitted then
                exit;
        MemberCard_l.Get(SalesCrMemoHeader_p."LSC Member Card No.");
        if not MemberCardManagement_l.ValidateCard(MemberCard_l, MessageText_l) then
            Error(MessageText_l);

        MemberPointEntry_l.Reset;
        MemberPointEntry_l.SetRange("Source Type", MemberPointEntry_l."Source Type"::"Credit Memo");
        MemberPointEntry_l.SetRange("Document No.", SalesCrMemoHeader_p."No.");
        if MemberPointEntry_l.FindFirst then
            exit; //Already processed

        if not MemberManagementSetup_l.FindFirst then
            Clear(MemberManagementSetup_l);

        if SalesCrMemoHeader_p."Currency Code" <> '' then
            CurrencyFactor_l := SalesCrMemoHeader_p."Currency Factor"
        else
            CurrencyFactor_l := 1;

        SalesCrMemoLine_l.Reset;
        SalesCrMemoLine_l.SetRange("Document No.", SalesCrMemoHeader_p."No.");
        SalesCrMemoLine_l.SetRange(Type, SalesCrMemoLine_l.Type::Item);
        SalesCrMemoLine_l.SetFilter(Quantity, '<>%1', 0);
        if SalesCrMemoLine_l.FindSet then
            repeat
                if PosCalcMemberPoints_l.CalcPoints(SalesCrMemoHeader_p."Currency Code", SalesCrMemoLine_l."Posting Date",
                  SalesCrMemoLine_l."Item Category Code", SalesCrMemoLine_l."LSC Retail Product Code", SalesCrMemoLine_l."No.",
                   MemberCard_l, FindActivePriceGroup(MemberCard_l), MemberPointSetup_l)
                then begin
                    if MemberManagementSetup_l."Amount Type for Point Calc." = MemberManagementSetup_l."Amount Type for Point Calc."::"Gross Amount" then
                        AmountBase_l := SalesCrMemoLine_l."Amount Including VAT" / CurrencyFactor_l
                    else
                        AmountBase_l := SalesCrMemoLine_l.Amount / CurrencyFactor_l;

                    if MemberPointSetup_l."Base Calculation on" = MemberPointSetup_l."Base Calculation on"::Amount then
                        ItemPoints_l := -Round(AmountBase_l * MemberPointSetup_l.Points / MemberPointSetup_l."Unit Rate", 0.01)
                    else
                        ItemPoints_l := -Round(SalesCrMemoLine_l.Quantity * MemberPointSetup_l.Points / MemberPointSetup_l."Unit Rate", 0.01);
                end;

                if ItemPoints_l <> 0 then begin
                    if MemberPointSetup_l."Points Type" = MemberPointSetup_l."Points Type"::"Award Points" then begin
                        AwardPoints_l := AwardPoints_l + ItemPoints_l;
                        SalesCrMemoLine_l."LSC Member Points Type" := SalesCrMemoLine_l."LSC Member Points Type"::"Award Points";
                    end else begin
                        OtherPoints_l := OtherPoints_l + ItemPoints_l;
                        SalesCrMemoLine_l."LSC Member Points Type" := SalesCrMemoLine_l."LSC Member Points Type"::"Other Points";
                    end;
                    SalesCrMemoLine_l."LSC Member Points" := ItemPoints_l;
                    SalesCrMemoLine_l.Modify;
                end;

            until SalesCrMemoLine_l.Next = 0;

        AddMemberPointEntry(AwardPoints_l, true, false, SalesCrMemoHeader_p."No.", SalesCrMemoHeader_p."LSC Store No.",
          SalesCrMemoHeader_p."Posting Date", MemberCard_l);
        AddMemberPointEntry(OtherPoints_l, false, false, SalesCrMemoHeader_p."No.", SalesCrMemoHeader_p."LSC Store No.",
          SalesCrMemoHeader_p."Posting Date", MemberCard_l);

        AddMemberSalesEntryFromCrMemo(SalesCrMemoHeader_p);
    end;

    [Scope('OnPrem')]
    procedure AddMemberSalesEntryFromCrMemo(SalesCrMemoHeader_p: Record "Sales Cr.Memo Header")
    var
        MemberSalesEntry_l: Record "LSC Member Sales Entry";
        SalesCrMemoLine_l: Record "Sales Cr.Memo Line";
        MemberCard_l: Record "LSC Membership Card";
        TransID_l: Integer;
        CurrencyFactor_l: Decimal;
        FBPUtility_l: Codeunit "LSC FBP Utility";
    begin
        MemberCard_l.Get(SalesCrMemoHeader_p."LSC Member Card No.");
        TransID_l := NextTransID;

        if SalesCrMemoHeader_p."Currency Code" <> '' then
            CurrencyFactor_l := SalesCrMemoHeader_p."Currency Factor"
        else
            CurrencyFactor_l := 1;

        SalesCrMemoLine_l.Reset;
        SalesCrMemoLine_l.SetRange("Document No.", SalesCrMemoHeader_p."No.");
        SalesCrMemoLine_l.SetFilter(Amount, '<>%1', 0);
        if SalesCrMemoLine_l.FindSet then
            repeat
                MemberSalesEntry_l.Init;
                MemberSalesEntry_l."Entry No." := TransID_l;
                MemberSalesEntry_l."Line No." := SalesCrMemoLine_l."Line No.";
                MemberSalesEntry_l."Source Type" := MemberSalesEntry_l."Source Type"::"Credit Memo";
                MemberSalesEntry_l."Document No." := SalesCrMemoLine_l."Document No.";
                MemberSalesEntry_l."Member Account No." := MemberCard_l."Account No.";
                MemberSalesEntry_l."Member Contact No." := MemberCard_l."Contact No.";
                MemberSalesEntry_l."Member Card No." := SalesCrMemoHeader_p."LSC Member Card No.";
                MemberSalesEntry_l."Member Club" := MemberCard_l."Club Code";
                MemberSalesEntry_l."Member Scheme" := MemberCard_l."Scheme Code";
                MemberSalesEntry_l.Quantity := SalesCrMemoLine_l.Quantity;
                MemberSalesEntry_l."Net Amount" := SalesCrMemoLine_l.Amount / CurrencyFactor_l;
                MemberSalesEntry_l."Gross Amount" := SalesCrMemoLine_l."Amount Including VAT" / CurrencyFactor_l;
                MemberSalesEntry_l."Discount Amount" := -SalesCrMemoLine_l."Line Discount Amount" / CurrencyFactor_l;
                MemberSalesEntry_l."Cost Amount" := SalesCrMemoLine_l."Unit Cost (LCY)" * SalesCrMemoLine_l.Quantity;
                MemberSalesEntry_l."Points Type" := SalesCrMemoLine_l."LSC Member Points Type";
                MemberSalesEntry_l.Points := SalesCrMemoLine_l."LSC Member Points";
                MemberSalesEntry_l.Date := SalesCrMemoHeader_p."Posting Date";
                MemberSalesEntry_l."Item No." := SalesCrMemoLine_l."No.";
                MemberSalesEntry_l."Item Variant Code" := SalesCrMemoLine_l."Variant Code";
                MemberSalesEntry_l."Item Category Code" := SalesCrMemoLine_l."Item Category Code";
                MemberSalesEntry_l."Retail Product Code" := SalesCrMemoLine_l."LSC Retail Product Code";
                MemberSalesEntry_l."Store No." := SalesCrMemoHeader_p."LSC Store No.";
                MemberSalesEntry_l.Description := SalesCrMemoLine_l.Description;
                if MemberSalesEntry_l.Insert(true) then;

                FBPUtility_l.ProcessMemberSalesEntry(MemberSalesEntry_l);
            until SalesCrMemoLine_l.Next = 0;
    end;

    [Scope('OnPrem')]
    procedure AddMemberPointEntry(Points_p: Decimal; AwardPoints_p: Boolean; Invoice_p: Boolean; DocumentNo_p: Code[20]; StoreNo_p: Code[10]; PostingDate_p: Date; MemberCard_p: Record "LSC Membership Card")
    var
        MemberClub_l: Record "LSC Member Club";
        MemberPointJnlLine_l: Record "LSC Member Point Jnl. Line";
        PointJnlPostLine_l: Codeunit "LSC Point Jnl.-Post Line";
    begin
        if Points_p = 0 then
            exit;

        MemberClub_l.Get(MemberCard_p."Club Code");

        MemberPointJnlLine_l.Init;
        MemberPointJnlLine_l.Type := MemberPointJnlLine_l.Type::Sales;
        MemberPointJnlLine_l.Points := RoundPoints(Points_p, MemberClub_l);
        if AwardPoints_p then
            MemberPointJnlLine_l."Point Type" := MemberPointJnlLine_l."Point Type"::"Award Points"
        else
            MemberPointJnlLine_l."Point Type" := MemberPointJnlLine_l."Point Type"::"Other Points";
        if Invoice_p then
            MemberPointJnlLine_l."Source Type" := MemberPointJnlLine_l."Source Type"::"Sales Invoice"
        else
            MemberPointJnlLine_l."Source Type" := MemberPointJnlLine_l."Source Type"::"Credit Memo";
        MemberPointJnlLine_l."Document No." := DocumentNo_p;
        MemberPointJnlLine_l."Store No." := StoreNo_p;
        MemberPointJnlLine_l.Date := PostingDate_p;
        MemberPointJnlLine_l."Account No." := MemberCard_p."Account No.";
        MemberPointJnlLine_l."Contact No" := MemberCard_p."Contact No.";
        MemberPointJnlLine_l."Card No." := MemberCard_p."Card No.";
        PointJnlPostLine_l.RunWithCheck(MemberPointJnlLine_l);
    end;

    procedure AddMemberPointEntryCustomerOrder(Points: Decimal; AwardPoints: Boolean; Redemption: Boolean; CustomerOrderHeader: Record "LSC Customer Order Header")
    var
        MemberClub: Record "LSC Member Club";
        MembershipCard: Record "LSC Membership Card";
        MemberPointJnlLine: Record "LSC Member Point Jnl. Line";
        PointJnlPostLine: Codeunit "LSC Point Jnl.-Post Line";
    begin
        if Points = 0 then
            exit;
        MembershipCard.Get(CustomerOrderHeader."Member Card No.");
        MemberClub.Get(MembershipCard."Club Code");

        MemberPointJnlLine.Init;
        if Redemption then
            MemberPointJnlLine.Type := MemberPointJnlLine.Type::Redemption
        else
            MemberPointJnlLine.Type := MemberPointJnlLine.Type::Sales;
        MemberPointJnlLine.Date := Today;
        MemberPointJnlLine."Source Type" := MemberPointJnlLine."Source Type"::"Customer Order";
        MemberPointJnlLine."Document No." := CustomerOrderHeader."Document ID";
        MemberPointJnlLine."Account No." := MembershipCard."Account No.";
        MemberPointJnlLine."Contact No" := MembershipCard."Contact No.";
        MemberPointJnlLine."Card No." := MembershipCard."Card No.";
        if AwardPoints then
            MemberPointJnlLine."Point Type" := MemberPointJnlLine."Point Type"::"Award Points"
        else
            MemberPointJnlLine."Point Type" := MemberPointJnlLine."Point Type"::"Other Points";
        MemberPointJnlLine.Points := RoundPoints(Points, MemberClub);
        MemberPointJnlLine."Point Value" := MemberClub."Point Value";
        MemberPointJnlLine."Total Value" := MemberPointJnlLine.Points * MemberPointJnlLine."Point Value";
        MemberPointJnlLine."Store No." := CustomerOrderHeader."Created at Store";
        PointJnlPostLine.RunWithCheck(MemberPointJnlLine);
    end;

    [Scope('OnPrem')]
    procedure AddMemberPointEntryPOS(Points_p: Decimal; AwardPoints_p: Boolean; Redemption_p: Boolean; TransHeader_p: Record "LSC Transaction Header")
    var
        MemberCard_l: Record "LSC Membership Card";
        MemberClub_l: Record "LSC Member Club";
        MemberPointJnlLine_l: Record "LSC Member Point Jnl. Line";
        PointJnlPostLine_l: Codeunit "LSC Point Jnl.-Post Line";
        TransSalesEntry: Record "LSC Trans. Sales Entry";
    begin
        if Points_p = 0 then
            exit;

        MemberCard_l.Get(TransHeader_p."Member Card No.");
        MemberClub_l.Get(MemberCard_l."Club Code");

        MemberPointJnlLine_l.Init;
        if Redemption_p then
            MemberPointJnlLine_l.Type := MemberPointJnlLine_l.Type::Redemption
        else
            MemberPointJnlLine_l.Type := MemberPointJnlLine_l.Type::Sales;
        MemberPointJnlLine_l.Date := TransHeader_p.Date;
        MemberPointJnlLine_l."Document No." := TransHeader_p."Receipt No.";
        MemberPointJnlLine_l."Account No." := MemberCard_l."Account No.";
        MemberPointJnlLine_l."Contact No" := MemberCard_l."Contact No.";
        MemberPointJnlLine_l."Card No." := MemberCard_l."Card No.";
        if AwardPoints_p then
            MemberPointJnlLine_l."Point Type" := MemberPointJnlLine_l."Point Type"::"Award Points"
        else
            MemberPointJnlLine_l."Point Type" := MemberPointJnlLine_l."Point Type"::"Other Points";
        MemberPointJnlLine_l.Points := RoundPoints(Points_p, MemberClub_l);
        MemberPointJnlLine_l."Point Value" := MemberClub_l."Point Value";
        MemberPointJnlLine_l."Total Value" := MemberPointJnlLine_l.Points * MemberPointJnlLine_l."Point Value";
        MemberPointJnlLine_l."Source Type" := MemberPointJnlLine_l."Source Type"::"POS Transaction";
        MemberPointJnlLine_l."Store No." := TransHeader_p."Store No.";
        MemberPointJnlLine_l."POS Terminal No." := TransHeader_p."POS Terminal No.";
        MemberPointJnlLine_l."Transaction No." := TransHeader_p."Transaction No.";
        TransSalesEntry.setrange("Transaction No.", TransHeader_p."Transaction No.");
        if TransSalesEntry.findfirst then
            MemberPointJnlLine_l."Original Transaction No." := TransSalesEntry."Orig Trans No.";
        PointJnlPostLine_l.RunWithCheck(MemberPointJnlLine_l);
    end;

    [Scope('OnPrem')]
    procedure NextTransID(): Integer
    var
        MemberSalesEntry_l: Record "LSC Member Sales Entry";
        TransID_l: Integer;
    begin
        if MemberSalesEntry_l.FindLast then
            TransID_l := MemberSalesEntry_l."Entry No." + 1
        else
            TransID_l := 1;
        exit(TransID_l);
    end;

    [Scope('OnPrem')]
    procedure FindActivePriceGroup(MemberCard: Record "LSC Membership Card") PriceGroup: Code[10]
    var
        Account: Record "LSC Member Account";
        Scheme: Record "LSC Member Scheme";
        Club: Record "LSC Member Club";
    begin
        if Account.Get(MemberCard."Account No.") then
            if Account."Price Group" <> '' then
                exit(Account."Price Group");

        if Scheme.Get(MemberCard."Scheme Code") then
            if Scheme."Default Price Group" <> '' then
                exit(Scheme."Default Price Group");

        if Club.Get(MemberCard."Club Code") then
            exit(Club."Default Price Group")
        else
            exit('');
    end;

    [IntegrationEvent(false, false)]
    local procedure OnBeforeCheckTransactionDataOk(TransHeader: Record "LSC Transaction Header"; var ProcessOrderEntry: Record "LSC Member Process Order Entry"; var IsHandled: Boolean; var ReturnValue: Boolean)
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterInsertMemberSalesEntryFromTransHeader(var TransSalesEntry: Record "LSC Trans. Sales Entry"; var MemberCard: Record "LSC Membership Card"; var MemberSalesEntry: Record "LSC Member Sales Entry")
    begin
    end;

    [IntegrationEvent(false, false)]
    local procedure OnAfterInsertMemberSalesEntryFromSalesInvoice(var SalesInvoiceHeader: Record "Sales Invoice Header"; var SalesInvoiceLine: Record "Sales Invoice Line"; var MemberCard: Record "LSC Membership Card"; var MemberSalesEntry: Record "LSC Member Sales Entry")
    begin
    end;
}

