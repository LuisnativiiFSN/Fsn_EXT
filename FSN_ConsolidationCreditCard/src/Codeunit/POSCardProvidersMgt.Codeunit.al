codeunit 50100 "FSN POS Card Providers Mgt." //50025
{
    // WVILLALTA 9.20                      - Version 1.0
    // WVILLALTA 02.21                     - Bug fix, filter equal POS Terminal


    trigger OnRun()
    begin

        CheckTransOpen((TODAY - 1), 0);
        CheckTransOpen((TODAY - 2), 0);
        CheckTransOpen((TODAY - 3), 0);
    end;

    var
        Text001: Label 'Match Presition %1 %2';
        Text002: Label 'Amount  zero';
        Text003: Label '<Precision,2:2><Standard Format,2>';
        Text004: Label 'Mix Muliple vouchers';
        GlobalsPresitions: Option "None",Manual,"Amount Zero","Ref/Term/Auth/$/Date","Term/Auth/$/Date","Auth/$/Date","Ref/Auth/$/Date","Ref/Term/Auth/$","Ref/Term/Auth/$/Date/BIN","Ref/Auth/$/Date/BIN","Ref/Term/Auth/$/BIN","Term/Auth/$/BIN/Date","$/BIN/Date/Store","Term/$/Date/Store","Auth/BIN/Date","Auth/Date/Cust";
        Text005: Label 'partial %1';
        Text006: Label 'Process date %1 ?';
        Text007: Label '(-1D)';
        Text008: Label '+-30D';
        Text009: Label '+-5D';
        ProcessOption: Label '%1,Month %2 / %3';
        Text010: Label 'Must be pending';
        pVoucher: Record "FSN POS Card Providers";
        Text012: Label 'Remaining amount %1, in payment %2, is not successfull';
        Text013: Label 'Apply manual, user: %1';
        Text014: Label 'Special search. Date,Cust.(Group),Store,Amt MX';
        Text015: Label 'Spec. search. Date(+-30D),Auth.Code,Store,Amt';
        Text016: Label 'Spec. search. Cust.(Group),Store,Amt MX(+-1D)';
        Text017: Label 'Error in create link \voucher %1 %2 %3, \Transac. %4 %5 %6';
        Text018: Label 'Error in try inherit';
        Text019: Label 'Cant be use more vouchers in status %1, \Solutions: Use Inherit or Liquidate Consigment';
        Text020: Label 'Voucher is lower (%1) to amount request (%2)';
        MonthName: Option "0",January,February,March,April,May,June,July,August,September,October,November,December;
        Text021: Label 'Date Cant be Emtpy';
        Text022: Label 'Data Error, Parent amount %1 is lowerto invoice Amount %2';


    procedure CheckTransOpen(pDate: Date; pMaxRowsProcess: Integer): Integer
    var
        fromDate: Date;
        toDate: Date;
        PaymentEntry: Record "LSC Trans. Payment Entry";//"99001474";
        i: Integer;
        ProvidersVSClient: Record "FSN POS Card Prov. VS Customer";//"50026";
        OneDay: Boolean;
    begin
        IF (DMY2DATE(1, 10, 2020) > pDate) AND (pDate <> 0D) THEN
            //IF (DMY2DATE(1,6,2020) > pDate) AND (pDate <> 0D) THEN
            EXIT;

        IF pDate = 0D THEN BEGIN
            IF DMY2DATE(1, 10, 2020) >= TODAY THEN
                EXIT;

            fromDate := TODAY - 1;
            toDate := TODAY;
            OneDay := FALSE;
        END ELSE BEGIN
            toDate := pDate;
            fromDate := pDate;
            OneDay := TRUE;
        END;
        i := 1;

        PaymentEntry.RESET;
        PaymentEntry.SETCURRENTKEY(Date, "Tender Type");
        IF OneDay THEN
            PaymentEntry.SETRANGE(PaymentEntry.Date, toDate)
        ELSE
            PaymentEntry.SETFILTER(PaymentEntry.Date, '>=%1&<=%1', fromDate, toDate);

        PaymentEntry.SETFILTER(PaymentEntry."Tender Type", '5|20');//Static
        IF PaymentEntry.FINDSET THEN
            REPEAT
                IF PaymentEntry."Safe type" <> PaymentEntry."Safe type"::"Fixed Float" THEN
                    IF NOT ProvidersVSClient.GET(PaymentEntry."Store No.", PaymentEntry."POS Terminal No.", PaymentEntry."Transaction No.", PaymentEntry."Line No.")
                    THEN BEGIN
                        CreateTransOpen(PaymentEntry);
                        i += 1;
                    END;

            UNTIL (PaymentEntry.NEXT = 0);// OR (i > pMaxRowsProcess);
        EXIT(i - 1);
    end;


    procedure CreateTransOpen(pPaymentNone: Record "LSC Trans. Payment Entry")
    var
        NewPOSCardVSClient: Record "FSN POS Card Prov. VS Customer";
        CardEntry: Record "LSC POS Card Entry";//"99008987";
        POSCardReq: Record "FSN POS Card Request Entry";
        Transactions: Record "LSC Transaction Header";//"99001472";
        Custom: Record Customer;
        Ok: Boolean;
        xBIN: Code[10];
        xAuth: Code[10];
        xRefer: Text[30];
        xIsTransOk: Boolean;
        xAmtTmp: Text;
        xWorkStr: Text;
        xTerm: Text[20];
    begin
        NewPOSCardVSClient.RESET;
        CLEAR(NewPOSCardVSClient);
        CLEAR(Custom);
        CLEAR(Transactions);
        CLEAR(CardEntry);
        CLEAR(xBIN);
        CLEAR(xAuth);
        CLEAR(xRefer);
        CLEAR(xIsTransOk);
        CLEAR(xAmtTmp);

        IF NOT Transactions.GET(pPaymentNone."Store No.", pPaymentNone."POS Terminal No.", pPaymentNone."Transaction No.") THEN
            EXIT;

        IF Transactions."Transaction Type" <> Transactions."Transaction Type"::Sales THEN
            EXIT;

        IF pPaymentNone."Amount Tendered" <> 0 THEN begin
            CardEntry.reset();
            CardEntry.SetRange("Store No.", pPaymentNone."Store No.");
            CardEntry.SetRange("POS Terminal No.", pPaymentNone."POS Terminal No.");
            CardEntry.SetRange("Receipt No.", pPaymentNone."Receipt No.");
            CardEntry.SetRange("Line No.", pPaymentNone."Line No.");
            IF CardEntry.FindFirst() THEN BEGIN
                xBIN := CardEntry."FSN BIN No."; //"BIN No.";
                xAuth := CardEntry."Auth.code";
                xRefer := CardEntry."EFT Trans. No.";
                xIsTransOk := CardEntry."Authorisation Ok";
                xTerm := CardEntry."EFT Terminal ID";
            END ELSE BEGIN
                xAmtTmp := FORMAT(pPaymentNone."Amount Tendered", 0, Text003);
                xAmtTmp := DELCHR(xAmtTmp, '=', ',.');
                xWorkStr := PADSTR('0', 12, '0') + xAmtTmp;
                xAmtTmp := COPYSTR(xWorkStr, STRLEN(xWorkStr) - 12 + 1, 12);

                POSCardReq.RESET;
                POSCardReq.SETCURRENTKEY("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
                POSCardReq.SETRANGE(POSCardReq."Receipt No.", pPaymentNone."Receipt No.");
                POSCardReq.SETRANGE(POSCardReq."Line No.", pPaymentNone."Line No.");
                POSCardReq.SETRANGE(POSCardReq."Enter Input", xAmtTmp);
                POSCardReq.SETRANGE(POSCardReq."Response Web Ok", TRUE);
                IF POSCardReq.FINDFIRST THEN BEGIN
                    xBIN := POSCardReq.BIN;
                    xAuth := POSCardReq."Trans Authorization";
                    xRefer := POSCardReq."Trans Reference";
                    xIsTransOk := POSCardReq."Response Web Ok";
                    xTerm := POSCardReq."Terminal ID";
                END;
            END;
        end;
        NewPOSCardVSClient.INIT;
        NewPOSCardVSClient."Store No." := pPaymentNone."Store No.";
        NewPOSCardVSClient."POS Terminal No." := pPaymentNone."POS Terminal No.";
        NewPOSCardVSClient."Transaction No." := pPaymentNone."Transaction No.";
        NewPOSCardVSClient."Line No." := pPaymentNone."Line No.";
        NewPOSCardVSClient."Provider Entry No." := 0;
        NewPOSCardVSClient.Status := NewPOSCardVSClient.Status::Open;
        NewPOSCardVSClient.Close := FALSE;
        IF NOT Transactions."Sale Is Return Sale" AND (Transactions."Refund Receipt No." <> '') THEN
            NewPOSCardVSClient.VALIDATE(NewPOSCardVSClient.Status, NewPOSCardVSClient.Status::MatchReverse);

        NewPOSCardVSClient.Amount := pPaymentNone."Amount Tendered";
        NewPOSCardVSClient."Customer No." := Transactions."Customer No.";
        NewPOSCardVSClient."Customer Name" := CopyStr(Transactions."FSN Customer Name", 1, 50);  //"Razon Social";
        NewPOSCardVSClient."Trans. Date" := pPaymentNone.Date;
        NewPOSCardVSClient."Trans. Time" := pPaymentNone."Trans. Time";
        NewPOSCardVSClient."Is Return" := Transactions."Sale Is Return Sale";
        IF NewPOSCardVSClient."Customer Name" = '' THEN
            IF Transactions."Customer No." <> '' THEN
                IF Custom.GET(Transactions."Customer No.") THEN
                    NewPOSCardVSClient."Customer Name" := CopyStr(Custom.Name, 1, 50);

        NewPOSCardVSClient.NCF := Transactions."FSN NCF"; //NCF;
        NewPOSCardVSClient."Amount Invoice" := Transactions.Payment;
        NewPOSCardVSClient."Staff ID" := Transactions."Staff ID";
        NewPOSCardVSClient."Receipt No." := pPaymentNone."Receipt No.";

        NewPOSCardVSClient."Auth. Code" := DELCHR(UPPERCASE(xAuth), '=', ',. ');
        IF STRLEN(NewPOSCardVSClient."Auth. Code") < 6 THEN
            NewPOSCardVSClient."Auth. Code" := ZeroPad(NewPOSCardVSClient."Auth. Code", 6);

        NewPOSCardVSClient.BIN := xBIN;
        IF STRLEN(xBIN) < 6 THEN
            NewPOSCardVSClient.BIN := ZeroPad(xBIN, 6);
        NewPOSCardVSClient.BIN := DELCHR(UPPERCASE(NewPOSCardVSClient.BIN), '=', ',. ');
        NewPOSCardVSClient.BIN := COPYSTR(NewPOSCardVSClient.BIN, 1, 6);
        NewPOSCardVSClient."Terminal ID" := xTerm;
        NewPOSCardVSClient."Authorization Web Ok" := xIsTransOk;
        NewPOSCardVSClient."Reference No." := xRefer;
        IF NewPOSCardVSClient.Amount = 0 THEN BEGIN
            NewPOSCardVSClient.VALIDATE(Status, NewPOSCardVSClient.Status::Complete);
            NewPOSCardVSClient."Process Message" := CopyStr(Text002, 1, 80);
        END;
        NewPOSCardVSClient.INSERT;
    end;


    procedure ProcessTransactions(pDate: Date)
    var
        CardProviders: Record "FSN POS Card Providers";//"50025";
        CardVSClients: Record "FSN POS Card Prov. VS Customer";//"50026";
        TransHdr: Record "LSC Transaction Header";
        SelectMenu: Integer;
        InitDate: Date;
        ToDate: Date;
        CurrMonth: Integer;
    begin
        COMMIT;
        IF pDate = 0D THEN BEGIN
            MESSAGE(Text021);
            EXIT;
        END;

        CurrMonth := DATE2DMY(pDate, 2);
        MonthName := CurrMonth;
        SelectMenu := STRMENU(STRSUBSTNO(ProcessOption, FORMAT(pDate), FORMAT(MonthName), DATE2DMY(pDate, 3)), 1);

        IF SelectMenu = 0 THEN
            EXIT;

        IF SelectMenu = 2 THEN BEGIN
            IF CurrMonth = 12 THEN BEGIN
                InitDate := DMY2DATE(1, 12, DATE2DMY(pDate, 3));
                ToDate := DMY2DATE(31, 12, DATE2DMY(pDate, 3));
            END ELSE BEGIN
                InitDate := DMY2DATE(1, CurrMonth, DATE2DMY(pDate, 3));
                ToDate := DMY2DATE(1, CurrMonth + 1, DATE2DMY(pDate, 3));
                ToDate := CALCDATE('-1D', ToDate);
            END;
        END;

        CardProviders.RESET;
        CardProviders.SETCURRENTKEY(Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask");
        CardProviders.SETRANGE(CardProviders.Status, CardProviders.Status::Open);
        CardProviders.SETRANGE(CardProviders."Amount Transaction", 0);
        CardProviders.SETRANGE(CardProviders."Reference No.", '');
        CardProviders.DELETEALL;

        ProcessingMatchReverse;

        CardProviders.RESET;
        CardProviders.SETCURRENTKEY(Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask");
        CardProviders.SETRANGE(CardProviders.Status, CardProviders.Status::Open);
        CardProviders.SETRANGE(CardProviders."Is Reverse", TRUE);
        IF CardProviders.FIND('-') THEN
            REPEAT
                ProcessingVoucherReverse(CardProviders);
            UNTIL CardProviders.NEXT = 0;


        CardProviders.RESET;
        CardProviders.SETCURRENTKEY(Close, "Date Key");
        CardProviders.SETRANGE(CardProviders.Close, FALSE);
        IF SelectMenu = 1 THEN
            CardProviders.SETRANGE(CardProviders."Date Key", pDate);
        IF SelectMenu = 2 THEN
            CardVSClients.SETFILTER(CardVSClients."Trans. Date", '>=%1&<=%2', InitDate, ToDate);
        IF CardProviders.FIND('-') THEN
            REPEAT
                ProcessingVouchersOpen(CardProviders);
                COMMIT;
            UNTIL CardProviders.NEXT = 0;

        CardVSClients.RESET;
        CardVSClients.SETCURRENTKEY("Trans. Date", Close);
        IF SelectMenu = 1 THEN
            CardVSClients.SETRANGE(CardVSClients."Trans. Date", pDate);
        IF SelectMenu = 2 THEN
            CardVSClients.SETFILTER(CardVSClients."Trans. Date", '>=%1&<=%2', InitDate, ToDate);
        CardVSClients.SETRANGE(CardVSClients.Close, FALSE);
        IF CardVSClients.FIND('-') THEN
            REPEAT
                IF NOT CardVSClients."Is Return" THEN
                    ProcessingOpen(CardVSClients);
                COMMIT;
            UNTIL CardVSClients.NEXT = 0;

        IF CardVSClients.FIND('-') THEN
            REPEAT
                IF NOT CardVSClients."Is Return" THEN
                    SpecialSearchCompare(CardVSClients);
                COMMIT;
            UNTIL CardVSClients.NEXT = 0;
    end;

    local procedure ProcessingOpen(pVSClient: Record "FSN POS Card Prov. VS Customer")
    var
        CardProviders: Record "FSN POS Card Providers";
        IfExists: Boolean;
        TerminalInt: Integer;
        AmtUnion: Decimal;
        ComssUnion: Decimal;
        MixCardProviders: Record "FSN POS Card Providers";
        IsDone: Boolean;
        AddParameterTxt: Text[10];
        TransHdr: Record "LSC Transaction Header";
    begin
        pVSClient.GET(pVSClient."Store No.", pVSClient."POS Terminal No.", pVSClient."Transaction No.", pVSClient."Line No.");
        IF pVSClient.Close THEN
            EXIT;

        IF NOT (pVSClient.Status = pVSClient.Status::Open) THEN
            EXIT;

        GlobalsPresitions := GlobalsPresitions::None;
        IF pVSClient.Amount = 0 THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Amount Zero";
            pVSClient.VALIDATE(Status, pVSClient.Status::Complete);
            pVSClient."Process Message" := CopyStr(Text002, 1, 80);
            pVSClient.MODIFY;
            EXIT;
        END;

        IF pVSClient.Status = pVSClient.Status::Open THEN
            IF TransHdr.GET(pVSClient."Store No.", pVSClient."POS Terminal No.", pVSClient."Transaction No.") THEN
                IF TransHdr."Refund Receipt No." <> '' THEN BEGIN
                    pVSClient.VALIDATE(Status, pVSClient.Status::MatchReverse);
                    pVSClient."Process Message" := '';
                    pVSClient.MODIFY;
                    EXIT;
                END;

        CardProviders.RESET;
        CardProviders.SETCURRENTKEY(Status, "Reference No.", "Auth. Code", "Amount Transaction", "Terminal ID");
        CardProviders.SETRANGE(CardProviders.Status, CardProviders.Status::Open);
        CardProviders.SETRANGE(CardProviders."Reference No.", pVSClient."Reference No.");
        CardProviders.SETRANGE(CardProviders."Auth. Code", pVSClient."Auth. Code");
        CardProviders.SETRANGE(CardProviders."Amount Transaction", pVSClient.Amount);
        CardProviders.SETRANGE(CardProviders."Terminal ID", pVSClient."Terminal ID");
        CardProviders.SETRANGE(CardProviders."Date Key", pVSClient."Trans. Date");
        CardProviders.SETRANGE(CardProviders."Parent Entry No.", 0);//Only parents without inherit
        IfExists := CardProviders.FINDFIRST;
        IF IfExists THEN
            GlobalsPresitions := GlobalsPresitions::"Ref/Term/Auth/$/Date";

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Term/Auth/$/Date";
            CardProviders.SETRANGE(CardProviders."Reference No.");
            IfExists := CardProviders.FINDFIRST;
        END;
        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Ref/Auth/$/Date";
            CardProviders.SETRANGE(CardProviders."Reference No.", pVSClient."Reference No.");
            CardProviders.SETRANGE(CardProviders."Terminal ID");
            IfExists := CardProviders.FINDFIRST;
        END;
        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Auth/$/Date";
            CardProviders.SETRANGE(CardProviders."Reference No.");
            IfExists := CardProviders.FINDFIRST;
        END;
        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Ref/Term/Auth/$";
            CardProviders.SETRANGE(CardProviders."Reference No.", pVSClient."Reference No.");
            CardProviders.SETRANGE(CardProviders."Terminal ID", pVSClient."Terminal ID");
            CardProviders.SETRANGE(CardProviders."Date Key");
            IfExists := CardProviders.FINDFIRST;
        END;

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Ref/Term/Auth/$";
            IF EVALUATE(TerminalInt, pVSClient."Terminal ID") THEN BEGIN
                CardProviders.SETRANGE(CardProviders."Terminal ID", FORMAT(TerminalInt));
                IfExists := CardProviders.FINDFIRST;
            END;
        END;

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Term/Auth/$/Date";
            CardProviders.SETRANGE(CardProviders."Reference No.");
            CardProviders.SETRANGE(CardProviders."Date Key", pVSClient."Trans. Date");
            IfExists := CardProviders.FINDFIRST;
        END;

        CLEAR(AddParameterTxt);
        IF NOT IfExists THEN BEGIN
            AddParameterTxt := Text008;
            GlobalsPresitions := GlobalsPresitions::"Term/Auth/$/Date";
            CardProviders.SETFILTER(CardProviders."Date Key", '>=%1&<=%2', CALCDATE('-30D', pVSClient."Trans. Date"), CALCDATE('+30D', pVSClient."Trans. Date"));
            IF NOT CardProviders.FINDFIRST THEN
                CardProviders.SETRANGE(CardProviders."Terminal ID", pVSClient."Terminal ID");
            IfExists := CardProviders.FINDFIRST;
        END;

        IF IfExists THEN BEGIN
            CreateLinkVoucher(CardProviders, pVSClient, STRSUBSTNO(Text001, FORMAT(GlobalsPresitions), AddParameterTxt), 0);
            EXIT;
        END;

        CLEAR(AddParameterTxt);
        IF NOT IfExists THEN BEGIN
            //Mix voucher
            CardProviders.SETRANGE(CardProviders."Terminal ID");
            CardProviders.SETFILTER(CardProviders."Amount Transaction", '<%1', pVSClient.Amount);
            IF CardProviders.FINDFIRST AND (pVSClient.Status IN [pVSClient.Status::Open]) THEN BEGIN //Search First
                IF CardProviders."Entry No." = 0 THEN BEGIN
                    CardProviders.SetEntryNo;
                    CardProviders.MODIFY;
                END;

                IF CardProviders."Entry No." = 0 THEN
                    EXIT;

                AmtUnion := 0;
                MixCardProviders.RESET;
                MixCardProviders.SETCURRENTKEY("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
                MixCardProviders.SETRANGE(MixCardProviders."Card Mask", CardProviders."Card Mask");
                MixCardProviders.SETRANGE(MixCardProviders."Retailer ID", CardProviders."Retailer ID");
                MixCardProviders.SETRANGE(MixCardProviders."Date Key", CardProviders."Date Key");
                MixCardProviders.SETRANGE(MixCardProviders.Status, MixCardProviders.Status::Open);
                MixCardProviders.CALCSUMS(MixCardProviders."Amount Transaction", MixCardProviders."Amount Commission");
                AmtUnion := MixCardProviders."Amount Transaction";
                ComssUnion := MixCardProviders."Amount Commission";

                IF AmtUnion = pVSClient.Amount THEN BEGIN
                    IsDone := FALSE;
                    IF MixCardProviders.FIND('-') THEN
                        REPEAT
                            MixCardProviders."Count Records" := 0;
                            MixCardProviders."Amount In Payments" := 0;
                            MixCardProviders."Parent Entry No." := CardProviders."Entry No.";
                            MixCardProviders."Parent Auth. Code" := CardProviders."Auth. Code";
                            MixCardProviders."Parent Amt. Comission" := ComssUnion;
                            MixCardProviders."Parent Amount" := AmtUnion;
                            IF (MixCardProviders."Auth. Code" = CardProviders."Auth. Code") AND (MixCardProviders."Entry No." = CardProviders."Entry No.") THEN
                                MixCardProviders.VALIDATE(MixCardProviders.Status, MixCardProviders.Status::Open)
                            ELSE
                                MixCardProviders.VALIDATE(MixCardProviders.Status, MixCardProviders.Status::Inherit);
                            MixCardProviders.MODIFY;
                            IsDone := TRUE;
                        UNTIL MixCardProviders.NEXT = 0;

                    IF IsDone THEN BEGIN

                        CardProviders.GET(CardProviders."Record Type", CardProviders."Date Key", CardProviders."Terminal ID", CardProviders."Auth. Code"
                          , CardProviders."Reference No.", CardProviders."Amount Transaction");
                        //CardProviders."Amount In Payments" := AmtUnion;
                        //CardProviders."Count Records" := 1;
                        //CardProviders.MODIFY;
                        pVSClient.GET(pVSClient."Store No.", pVSClient."POS Terminal No.", pVSClient."Transaction No.", pVSClient."Line No.");

                        CreateLinkVoucher(CardProviders, pVSClient, Text004, AmtUnion);
                        CardProviders.GET(CardProviders."Record Type", CardProviders."Date Key", CardProviders."Terminal ID"
                          , CardProviders."Auth. Code", CardProviders."Reference No.", CardProviders."Amount Transaction");
                        IF CardProviders."Amount In Payments" <> pVSClient.Amount THEN
                            ERROR(Text018);
                        EXIT;
                    END;
                END;
            END;
        END;
    end;

    local procedure ProcessingVouchersOpen(pVoucher: Record "FSN POS Card Providers")
    var
        VSClient: Record "FSN POS Card Prov. VS Customer";
        IfExists: Boolean;
        OldVoucher: Record "FSN POS Card Providers";
        OldVSClient: Record "FSN POS Card Prov. VS Customer";
        AmtResult: Decimal;
        AmtUnion: Decimal;
        IsDone: Boolean;
        AddParameterTxt: Text[10];
    begin
        pVoucher.GET(pVoucher."Record Type", pVoucher."Date Key", pVoucher."Terminal ID"
          , pVoucher."Auth. Code", pVoucher."Reference No.", pVoucher."Amount Transaction");

        IF NOT (pVoucher.Status = pVoucher.Status::Open) THEN
            EXIT;

        IF pVoucher."Is Reverse" THEN
            EXIT;

        AmtResult := pVoucher."Amount Transaction" - pVoucher."Amount In Payments";
        IF AmtResult <= 0 THEN
            EXIT;

        GlobalsPresitions := GlobalsPresitions::None;
        VSClient.SETCURRENTKEY("Terminal ID", "Auth. Code", BIN, Status, "Trans. Date", Amount);
        VSClient.SETRANGE(VSClient."Terminal ID", pVoucher."Terminal ID");
        VSClient.SETRANGE(VSClient."Auth. Code", pVoucher."Auth. Code");
        VSClient.SETRANGE(VSClient.BIN, COPYSTR(pVoucher."Card Mask", 1, 6));
        VSClient.SETRANGE(VSClient.Status, VSClient.Status::Open);

        VSClient.SETRANGE(VSClient."Reference No.", pVoucher."Reference No.");
        VSClient.SETRANGE(VSClient."Trans. Date", pVoucher."Date Key");
        VSClient.SETRANGE(VSClient.Amount, AmtResult);
        IfExists := VSClient.FINDFIRST;

        IF IfExists THEN
            GlobalsPresitions := GlobalsPresitions::"Ref/Term/Auth/$/Date/BIN";

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Ref/Auth/$/Date/BIN";
            VSClient.SETRANGE(VSClient."Terminal ID");
            IfExists := VSClient.FINDFIRST;
        END;

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Ref/Term/Auth/$/BIN";
            VSClient.SETRANGE(VSClient."Terminal ID", pVoucher."Terminal ID");
            VSClient.SETRANGE(VSClient."Trans. Date");
            IfExists := VSClient.FINDFIRST;
        END;

        IF NOT IfExists THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Term/Auth/$/BIN/Date";
            VSClient.SETRANGE(VSClient."Reference No.");
            VSClient.SETRANGE(VSClient."Trans. Date", pVoucher."Date Key");
            IfExists := VSClient.FINDFIRST;
        END;

        CLEAR(AddParameterTxt);
        IF NOT IfExists THEN BEGIN
            OldVoucher.RESET;
            OldVoucher.SETCURRENTKEY(Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask");
            OldVoucher.SETRANGE(OldVoucher."Date Key", pVoucher."Date Key");
            OldVoucher.SETRANGE(OldVoucher."Terminal ID", pVoucher."Terminal ID");
            OldVoucher.SETRANGE(OldVoucher.Status, OldVoucher.Status::Complete);
            IF NOT OldVoucher.FINDFIRST THEN BEGIN
                OldVoucher.SETRANGE(OldVoucher."Date Key", pVoucher."Date Key" - 1);
                AddParameterTxt := Text007;
            END;
            IF OldVoucher.FINDFIRST THEN BEGIN

                OldVSClient.RESET;
                OldVSClient.SETCURRENTKEY("Provider Entry No.", "Auth. Code");
                OldVSClient.SETRANGE(OldVSClient."Provider Entry No.", OldVoucher."Entry No.");
                OldVSClient.SETRANGE(OldVSClient."Auth. Code", OldVoucher."Auth. Code");
                IF OldVSClient.FINDFIRST THEN BEGIN
                    GlobalsPresitions := GlobalsPresitions::"$/BIN/Date/Store";
                    VSClient.SETRANGE(VSClient."Auth. Code");
                    VSClient.SETRANGE(VSClient."Terminal ID");
                    VSClient.SETRANGE(VSClient."Store No.", OldVSClient."Store No.");
                    IF NOT VSClient.FINDFIRST THEN BEGIN
                        GlobalsPresitions := GlobalsPresitions::"Term/$/Date/Store";
                        VSClient.SETRANGE(VSClient.BIN);
                    END;
                    IfExists := VSClient.FINDFIRST;

                END;
            END;
        END;

        IF IfExists THEN
            CreateLinkVoucher(pVoucher, VSClient, STRSUBSTNO(Text001, FORMAT(GlobalsPresitions), AddParameterTxt), 0);

        CLEAR(AddParameterTxt);
        IF NOT IfExists AND (pVoucher."Parent Entry No." = 0) THEN BEGIN
            GlobalsPresitions := GlobalsPresitions::"Auth/BIN/Date";

            VSClient.SETRANGE(VSClient."Store No.");
            VSClient.SETRANGE(VSClient."Terminal ID");
            VSClient.SETRANGE(VSClient."Auth. Code", pVoucher."Auth. Code");
            VSClient.SETFILTER(VSClient.Amount, '<%1', AmtResult);
            VSClient.SETRANGE(VSClient.BIN, COPYSTR(pVoucher."Card Mask", 1, 6));
            IF NOT VSClient.FINDFIRST THEN BEGIN
                AddParameterTxt := Text009;
                VSClient.SETFILTER(VSClient."Trans. Date", '>=%1&<=%2', CALCDATE('-5D', pVoucher."Date Key"), CALCDATE('+5D', pVoucher."Date Key"));
            END;
            IF NOT VSClient.FINDFIRST THEN BEGIN
                GlobalsPresitions := GlobalsPresitions::"Auth/Date/Cust";
                VSClient.SETRANGE(VSClient.BIN);
            END;
            IF VSClient.FINDFIRST THEN BEGIN
                IsDone := FALSE;
                OldVSClient.RESET;
                OldVSClient.SETCURRENTKEY("Store No.", "Customer No.", "Trans. Date", Status, Amount);
                OldVSClient.SETRANGE(OldVSClient."Store No.", VSClient."Store No.");
                OldVSClient.SETRANGE(OldVSClient."POS Terminal No.", VSClient."POS Terminal No.");
                OldVSClient.SETRANGE(OldVSClient."Customer No.", VSClient."Customer No.");
                OldVSClient.SETRANGE(OldVSClient."Trans. Date", VSClient."Trans. Date");
                OldVSClient.SETRANGE(OldVSClient.Status, OldVSClient.Status::Open);
                OldVSClient.CALCSUMS(OldVSClient.Amount);
                AmtUnion := OldVSClient.Amount;
                IF AmtUnion = pVoucher."Amount Transaction" THEN BEGIN
                    IF OldVSClient.FIND('-') THEN
                        REPEAT
                            CreateLinkVoucher(pVoucher, OldVSClient, STRSUBSTNO(Text001, FORMAT(GlobalsPresitions), STRSUBSTNO(Text005, AddParameterTxt)), 0);
                        UNTIL OldVSClient.NEXT = 0;
                END ELSE BEGIN
                    IF AddParameterTxt <> '' THEN
                        AddParameterTxt += ' MX'
                    ELSE
                        AddParameterTxt += 'MX';

                    OldVSClient.RESET;
                    OldVSClient.SETCURRENTKEY("Store No.", "Customer No.", "Trans. Date", Status, Amount);
                    OldVSClient.SETRANGE(OldVSClient."Auth. Code", VSClient."Auth. Code");
                    OldVSClient.SETRANGE(OldVSClient.BIN, VSClient.BIN);
                    OldVSClient.SETRANGE(OldVSClient."Customer No.", VSClient."Customer No.");
                    OldVSClient.SETRANGE(OldVSClient."Trans. Date", VSClient."Trans. Date");
                    OldVSClient.SETRANGE(OldVSClient.Status, OldVSClient.Status::Open);
                    OldVSClient.CALCSUMS(OldVSClient.Amount);
                    AmtUnion := OldVSClient.Amount;
                    IF AmtUnion = pVoucher."Amount Transaction" THEN BEGIN
                        IF OldVSClient.FIND('-') THEN
                            REPEAT
                                CreateLinkVoucher(pVoucher, OldVSClient, STRSUBSTNO(Text001, FORMAT(GlobalsPresitions), STRSUBSTNO(Text005, AddParameterTxt)), 0);
                            UNTIL OldVSClient.NEXT = 0;
                    END;
                END;
            END;
        END;
    end;


    procedure ProcessingMatchReverse()
    var
        TransHdr: Record "LSC Transaction Header";
        Ok_: Boolean;
        CardVSClient: Record "FSN POS Card Prov. VS Customer";
        CardVSOrigin: Record "FSN POS Card Prov. VS Customer";
        Vouchers: Record "FSN POS Card Providers";
        VoucherOrigin: Record "FSN POS Card Providers";
        qCardReverse: Query "FSN POS Card Prov. Processing";
        AmtTmp: Decimal;
        CountRec: Integer;
        OldEntryNo: Integer;
    begin
        CLEAR(qCardReverse);
        qCardReverse.OPEN;
        CardVSClient.RESET;
        CardVSOrigin.RESET;
        CardVSClient.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
        CardVSOrigin.SETCURRENTKEY("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");

        TransHdr.RESET;
        TransHdr.SETCURRENTKEY("Receipt No.", Date);
        VoucherOrigin.RESET;
        VoucherOrigin.SETCURRENTKEY("Entry No.", "Parent Entry No.");

        WHILE qCardReverse.READ DO BEGIN

            TransHdr.SETRANGE(TransHdr."Receipt No.", qCardReverse.Retrieved_from_Receipt_No);
            TransHdr.SETRANGE(TransHdr."Store No.", qCardReverse.Store_No);
            TransHdr.SETRANGE(TransHdr."POS Terminal No.", qCardReverse.POS_Terminal_No);//WVILLALTA 02.21-
                                                                                         //WVILLALTA 02.21+
            TransHdr.SETRANGE(TransHdr."Entry Status", 0);
            IF TransHdr.FINDFIRST THEN BEGIN

                CardVSOrigin.SETRANGE(CardVSOrigin."Store No.", TransHdr."Store No.");
                CardVSOrigin.SETRANGE(CardVSOrigin."POS Terminal No.", TransHdr."POS Terminal No.");
                CardVSOrigin.SETRANGE(CardVSOrigin."Transaction No.", TransHdr."Transaction No.");
                IF CardVSOrigin.FIND('-') THEN
                    REPEAT
                        DeleteLinkVoucherFromTransac(CardVSOrigin, CardVSOrigin.Status::MatchReverse);
                    UNTIL CardVSOrigin.NEXT = 0;

            END;

            CardVSClient.SETRANGE(CardVSClient."Store No.", qCardReverse.Store_No);
            CardVSClient.SETRANGE(CardVSClient."POS Terminal No.", qCardReverse.POS_Terminal_No);
            CardVSClient.SETRANGE(CardVSClient."Transaction No.", qCardReverse.Transaction_No);
            IF CardVSClient.FIND('-') THEN
                REPEAT
                    DeleteLinkVoucherFromTransac(CardVSClient, CardVSOrigin.Status::MatchReverse);
                UNTIL CardVSClient.NEXT = 0;

        END;
        qCardReverse.CLOSE;
    end;

    local procedure ProcessingVoucherReverse(pVoucher: Record "FSN POS Card Providers")
    var
        CardClient: Record "FSN POS Card Providers";
        VoucherOrigin: Record "FSN POS Card Providers";
    begin
        pVoucher.GET(pVoucher."Record Type", pVoucher."Date Key", pVoucher."Terminal ID"
          , pVoucher."Auth. Code", pVoucher."Reference No.", pVoucher."Amount Transaction");

        IF pVoucher.Close THEN
            EXIT;

        VoucherOrigin.RESET;
        VoucherOrigin.SETCURRENTKEY("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
        VoucherOrigin.SETRANGE(VoucherOrigin."Date Key", pVoucher."Date Key");
        VoucherOrigin.SETRANGE(VoucherOrigin."Terminal ID", pVoucher."Terminal ID");
        VoucherOrigin.SETRANGE(VoucherOrigin."Auth. Code", pVoucher."Auth. Code");
        VoucherOrigin.SETRANGE(VoucherOrigin."Reference No.", pVoucher."Reference No.");
        VoucherOrigin.SETRANGE(VoucherOrigin."Amount Transaction", -pVoucher."Amount Transaction");
        IF NOT VoucherOrigin.FIND('-') THEN
            VoucherOrigin.SETRANGE(VoucherOrigin."Date Key");
        IF VoucherOrigin.FIND('-') THEN BEGIN
            DeleteLinkVoucherFromVoucher(VoucherOrigin, CardClient.Status::Open);

            VoucherOrigin.GET(VoucherOrigin."Record Type", VoucherOrigin."Date Key", VoucherOrigin."Terminal ID"
              , VoucherOrigin."Auth. Code", VoucherOrigin."Reference No.", VoucherOrigin."Amount Transaction");
            IF (VoucherOrigin.Status = VoucherOrigin.Status::Open) AND (pVoucher.Status = pVoucher.Status::Open) THEN BEGIN
                pVoucher.VALIDATE(Status, pVoucher.Status::MatchReverse);
                pVoucher.MODIFY;
                VoucherOrigin.VALIDATE(VoucherOrigin.Status, VoucherOrigin.Status::MatchReverse);
                VoucherOrigin.MODIFY;
            END;
        END;
    end;


    procedure SpecialSearchCompare(pTransClient: Record "FSN POS Card Prov. VS Customer")
    var
        Vouchers: Record "FSN POS Card Providers";
        TransClient2: Record "FSN POS Card Prov. VS Customer";
        SumTrans_l: Decimal;
        POSSetupExt: Record "FSN POS Setup Extend";  //"50028";
    begin
        IF pTransClient.Close THEN
            EXIT;

        //Filter
        Vouchers.RESET;
        Vouchers.SETCURRENTKEY(Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask");
        Vouchers.SETRANGE(Vouchers."Auth. Code", pTransClient."Auth. Code");
        Vouchers.SETRANGE(Vouchers."Amount Transaction", pTransClient.Amount);
        Vouchers.SETRANGE(Vouchers."Store In Setup", pTransClient."Store No.");
        Vouchers.SETFILTER(Vouchers."Date Key", '>=%1|<=%2', CALCDATE('-30D', pTransClient."Trans. Date"), CALCDATE('+30D', pTransClient."Trans. Date"));
        Vouchers.SETRANGE(Vouchers.Status, Vouchers.Status::Open);
        IF Vouchers.FIND('-') THEN BEGIN
            CreateLinkVoucher(Vouchers, pTransClient, Text015, 0);
            EXIT;
        END;

        Vouchers.SETRANGE(Vouchers."Store Apply", pTransClient."Store No.");
        IF Vouchers.FIND('-') THEN BEGIN
            CreateLinkVoucher(Vouchers, pTransClient, Text015, 0);
            EXIT;
        END;

        TransClient2.RESET;
        TransClient2.SETCURRENTKEY("Store No.", "Customer No.", "Trans. Date", Status, Amount);
        TransClient2.SETRANGE(TransClient2."Store No.", pTransClient."Store No.");
        TransClient2.SETRANGE(TransClient2."Customer No.", pTransClient."Customer No.");
        TransClient2.SETRANGE(TransClient2."Trans. Date", pTransClient."Trans. Date");
        TransClient2.SETRANGE(TransClient2."Is Return", FALSE);
        TransClient2.SETRANGE(TransClient2.Status, TransClient2.Status::Open);
        TransClient2.CALCSUMS(TransClient2.Amount);
        SumTrans_l := TransClient2.Amount;

        Vouchers.RESET;
        Vouchers.SETCURRENTKEY(Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask");
        Vouchers.SETRANGE(Vouchers."Date Key", pTransClient."Trans. Date");
        Vouchers.SETRANGE(Vouchers."Store In Setup", pTransClient."Store No.");
        Vouchers.SETRANGE(Vouchers.Status, Vouchers.Status::Open);
        Vouchers.SETRANGE(Vouchers."Amount Transaction", SumTrans_l);
        IF Vouchers.FIND('-') THEN BEGIN
            IF TransClient2.FIND('-') THEN
                REPEAT
                    CreateLinkVoucher(Vouchers, TransClient2, Text014, 0);
                UNTIL TransClient2.NEXT = 0;
            EXIT;
        END ELSE BEGIN
            Vouchers.SETFILTER(Vouchers."Date Key", '>=%1|<=%2', CALCDATE('-1D', pTransClient."Trans. Date"), CALCDATE('+1D', pTransClient."Trans. Date"));
            IF Vouchers.FIND('-') THEN BEGIN
                IF TransClient2.FIND('-') THEN
                    REPEAT
                        CreateLinkVoucher(Vouchers, TransClient2, Text016, 0);
                    UNTIL TransClient2.NEXT = 0;
                EXIT;
            END ELSE BEGIN
                Vouchers.SETRANGE(Vouchers."Store Apply", pTransClient."Store No.");//Manual Filter
                IF Vouchers.FIND('-') THEN BEGIN
                    IF TransClient2.FIND('-') THEN
                        REPEAT
                            CreateLinkVoucher(Vouchers, TransClient2, Text016, 0);
                        UNTIL TransClient2.NEXT = 0;
                    EXIT;
                END;
            END;
        END;//Risk
    end;

    local procedure CreateLinkVoucher(pVoucher: Record "FSN POS Card Providers"; pVSClient: Record "FSN POS Card Prov. VS Customer"; pMessage: Text; pSumsInherit: Decimal)
    var
        AmtTmp: Decimal;
        RecCount: Integer;
        pVoucherInherit: Record "FSN POS Card Providers";
    begin
        pVoucher.GET(pVoucher."Record Type", pVoucher."Date Key", pVoucher."Terminal ID", pVoucher."Auth. Code"
          , pVoucher."Reference No.", pVoucher."Amount Transaction");

        IF pVoucher.Close OR pVSClient.Close OR (((pVSClient."Store No." = '') AND (pVSClient."Trans. Date" = 0D)) OR (pVSClient.Amount = 0)) THEN
            ERROR(STRSUBSTNO(Text017, pVoucher."Date Key", pVoucher."Auth. Code", pVoucher."Reference No."
              , pVSClient."Store No.", pVSClient."POS Terminal No.", pVSClient."Receipt No."));

        IF pVoucher."Entry No." = 0 THEN BEGIN
            pVoucher.SetEntryNo;
            pVoucher.MODIFY;
        END;
        IF (pVoucher."Parent Entry No." > 0) AND
          ((pVoucher."Parent Auth. Code" = '') OR
            (pSumsInherit = 0) OR
            (pVoucher."Parent Entry No." <> pVoucher."Entry No.")) THEN
            EXIT;

        pVSClient."Provider Entry No." := pVoucher."Entry No.";
        pVSClient."Auth. Code" := pVoucher."Auth. Code";
        pVSClient."Process Message" := CopyStr(pMessage, 1, 80);

        IF pVoucher."Parent Entry No." > 0 THEN BEGIN
            pVSClient."Provider Entry No." := pVoucher."Parent Entry No.";
            pVSClient."Auth. Code" := pVoucher."Parent Auth. Code";

            //IF pVSClient.Amount <= pSumsInherit THEN
            IF pVSClient.Amount <= (pVoucher."Parent Amount" - pVoucher."Amount In Payments") THEN
                pVSClient.VALIDATE(Status, pVSClient.Status::Complete)
            ELSE BEGIN
                pVSClient.VALIDATE(Status, pVSClient.Status::Partial);
                //pVSClient."Amount Pending" := pVSClient.Amount -  pSumsInherit;//Ext.
                pVSClient."Amount Pending" := pVSClient.Amount - (pVoucher."Parent Amount" - pVoucher."Amount In Payments");//Ext.
            END;

        END ELSE BEGIN

            IF pVSClient.Amount <= (pVoucher."Amount Transaction" - pVoucher."Amount In Payments") THEN
                pVSClient.VALIDATE(Status, pVSClient.Status::Complete)
            ELSE BEGIN
                pVSClient.VALIDATE(Status, pVSClient.Status::Partial);
                pVSClient."Amount Pending" := pVSClient.Amount - (pVoucher."Amount Transaction" - pVoucher."Amount In Payments");//Ext.
            END;

        END;
        pVSClient.MODIFY;

        AmtTmp := CalcTransInPayment(pVoucher, RecCount);
        pVoucher."Amount In Payments" := AmtTmp;
        pVoucher."Count Records" := RecCount;
        pVoucher."Store Apply" := pVSClient."Store No.";
        pVoucher."Last Customer No." := pVSClient."Customer No.";
        IF pVoucher."Parent Amount" > 0 THEN BEGIN

            IF pVoucher."Amount In Payments" = pVoucher."Parent Amount" THEN
                pVoucher.VALIDATE(Status, pVoucher.Status::Complete)
            ELSE
                IF pVoucher."Amount In Payments" < pVoucher."Parent Amount" THEN
                    pVoucher.VALIDATE(Status, pVoucher.Status::Partial)
                ELSE
                    IF pVoucher."Amount In Payments" > pVoucher."Parent Amount" THEN
                        ERROR(STRSUBSTNO(Text022, FORMAT(pVoucher."Parent Amount"), FORMAT(pVoucher."Amount In Payments")));

        END ELSE BEGIN

            IF pVoucher."Amount In Payments" = pVoucher."Amount Transaction" THEN
                pVoucher.VALIDATE(Status, pVoucher.Status::Complete)
            ELSE
                IF pVoucher."Amount In Payments" < pVoucher."Amount Transaction" THEN
                    pVoucher.VALIDATE(Status, pVoucher.Status::Partial)
                ELSE
                    IF pVoucher."Amount In Payments" > pVoucher."Amount Transaction" THEN
                        ERROR(STRSUBSTNO(Text022, FORMAT(pVoucher."Amount Transaction"), FORMAT(pVoucher."Amount In Payments")));
        END;

        pVoucher.MODIFY;

        pVoucherInherit.RESET;
        pVoucherInherit.SETRANGE(pVoucherInherit."Parent Entry No.", pVoucher."Entry No.");
        pVoucherInherit.SETRANGE(pVoucherInherit."Parent Auth. Code", pVoucher."Auth. Code");
        pVoucherInherit.MODIFYALL(pVoucherInherit."Store Apply", pVoucher."Store Apply", FALSE);
    end;


    procedure CheckCreateLink(pPaymentTrans: Record "FSN POS Card Prov. VS Customer"; pVoucher: Record "FSN POS Card Providers")
    var
        Sums_l: Decimal;
        pInherit: Record "FSN POS Card Providers";
        pPayUsers: Record "FSN POS Card Prov. VS Customer";
    begin
        IF pPaymentTrans.Close THEN
            pPaymentTrans.FIELDERROR(pPaymentTrans.Close, Text010);

        IF pVoucher.Close THEN
            pVoucher.FIELDERROR(pVoucher.Close, Text010);

        pVoucher.TESTFIELD(pVoucher."Is Reverse", FALSE);

        IF pPaymentTrans.Status = pPaymentTrans.Status::Partial THEN
            ERROR(STRSUBSTNO(Text019, FORMAT(pPaymentTrans.Status)));

        IF pVoucher."Parent Entry No." > 0 THEN BEGIN
            pInherit.RESET;
            pInherit.SETCURRENTKEY("Parent Entry No.", "Parent Auth. Code");
            pInherit.SETRANGE(pInherit."Parent Entry No.", pVoucher."Parent Entry No.");
            pInherit.SETRANGE(pInherit."Parent Auth. Code", pVoucher."Parent Auth. Code");
            pInherit.CALCSUMS(pInherit."Amount Transaction");
            Sums_l := pInherit."Amount Transaction";
        END ELSE
            Sums_l := pVoucher."Amount Transaction";

        pPayUsers.RESET;
        pPayUsers.SETCURRENTKEY("Provider Entry No.", "Auth. Code");
        pPayUsers.SETRANGE(pPayUsers."Provider Entry No.", pVoucher."Parent Entry No.");
        pPayUsers.SETRANGE(pPayUsers."Auth. Code", pVoucher."Parent Auth. Code");
        pPayUsers.SETRANGE(pPayUsers.Close, TRUE);
        pPayUsers.CALCSUMS(pPayUsers.Amount);
        IF NOT (pPaymentTrans.Amount <= (Sums_l - pPayUsers.Amount)) THEN
            IF NOT CONFIRM(STRSUBSTNO(Text020, FORMAT(Sums_l), pPaymentTrans.Amount)) THEN
                EXIT;
        //ERROR(STRSUBSTNO(Text012,FORMAT((Sums_l - pPayUsers.Amount)),FORMAT(pPaymentTrans.Amount)));

        CreateLinkVoucher(pVoucher, pPaymentTrans, STRSUBSTNO(Text013, COPYSTR(USERID, 1, 20)), Sums_l);
    end;

    local procedure ClearStatusVoucher(pVoucher: Record "FSN POS Card Providers")
    begin
        pVoucher.GET(pVoucher."Record Type", pVoucher."Date Key", pVoucher."Terminal ID", pVoucher."Auth. Code"
          , pVoucher."Reference No.", pVoucher."Amount Transaction");

        pVoucher."Count Records" := 0;
        pVoucher."Amount In Payments" := 0;
        pVoucher."Parent Entry No." := 0;
        pVoucher."Parent Auth. Code" := '';
        pVoucher."Parent Amount" := 0;
        //pVoucher."Store Apply" := '';
        pVoucher.VALIDATE(Status, pVoucher.Status::Open);
        pVoucher."Close Diff. Amount" := 0;
        pVoucher."Close Diff. Refund" := 0;
        pVoucher.MODIFY;
    end;

    local procedure ClearStatusTransPayment(pTransPay: Record "FSN POS Card Prov. VS Customer")
    var
        CardEntry: Record "LSC POS Card Entry";//"99008987";
    begin
        pTransPay.GET(pTransPay."Store No.", pTransPay."POS Terminal No.", pTransPay."Transaction No.", pTransPay."Line No.");

        pTransPay.VALIDATE(Status, pTransPay.Status::Open);
        CardEntry.Reset();
        CardEntry.SetRange("Store No.", pTransPay."Store No.");
        CardEntry.SetRange("POS Terminal No.", pTransPay."POS Terminal No.");
        CardEntry.SetRange("Receipt No.", pTransPay."Receipt No.");
        CardEntry.SetRange("Line No.", pTransPay."Line No.");
        IF CardEntry.FindFirst() THEN BEGIN
            pTransPay."Auth. Code" := CardEntry."Auth.code";
            pTransPay."Auth. Code" := DELCHR(UPPERCASE(pTransPay."Auth. Code"), '=', ',. ');
            IF STRLEN(pTransPay."Auth. Code") < 6 THEN
                pTransPay."Auth. Code" := ZeroPad(pTransPay."Auth. Code", 6);
        END;

        pTransPay."Process Message" := '';
        pTransPay."Provider Entry No." := 0;
        pTransPay."Consignment Amount" := 0;
        pTransPay."Amount Pending" := 0;
        pTransPay.MODIFY;
    end;


    procedure DeleteLinkVoucherFromVoucher(pVoucher: Record "FSN POS Card Providers"; pNewState: Integer)
    var
        pLinksVoucher: Record "FSN POS Card Providers";
        TransClient: Record "FSN POS Card Prov. VS Customer";
        EntryNo: Integer;
        Auth: Code[20];
        CardEntry: Record "LSC POS Card Entry";//"99008987";
    begin
        pVoucher.GET(pVoucher."Record Type", pVoucher."Date Key", pVoucher."Terminal ID"
          , pVoucher."Auth. Code", pVoucher."Reference No.", pVoucher."Amount Transaction");

        EntryNo := pVoucher."Entry No.";
        Auth := pVoucher."Auth. Code";

        pLinksVoucher.RESET;
        IF pVoucher."Parent Entry No." > 0 THEN BEGIN
            EntryNo := pVoucher."Parent Entry No.";
            Auth := pVoucher."Parent Auth. Code";

            pLinksVoucher.SETRANGE(pLinksVoucher."Parent Entry No.", EntryNo);
            pLinksVoucher.SETRANGE(pLinksVoucher."Parent Auth. Code", Auth);
        END ELSE BEGIN
            pLinksVoucher.SETRANGE(pLinksVoucher."Entry No.", EntryNo);
            pLinksVoucher.SETRANGE(pLinksVoucher."Auth. Code", Auth);
        END;

        IF pLinksVoucher.FIND('-') THEN
            REPEAT
                ClearStatusVoucher(pLinksVoucher);
            UNTIL pLinksVoucher.NEXT = 0;

        TransClient.RESET;
        TransClient.SETCURRENTKEY("Provider Entry No.", "Auth. Code");
        TransClient.SETRANGE(TransClient."Provider Entry No.", EntryNo);
        TransClient.SETRANGE(TransClient."Auth. Code", Auth);
        IF TransClient.FIND('-') THEN
            REPEAT
                ClearStatusTransPayment(TransClient);
            UNTIL TransClient.NEXT = 0;
    end;


    procedure DeleteLinkVoucherFromTransac(pTransClient: Record "FSN POS Card Prov. VS Customer"; pNewState: Integer)
    var
        Voucher: Record "FSN POS Card Providers";
        VoucherLink: Record "FSN POS Card Providers";
        EntryNo: Integer;
        Auth: Code[20];
    begin
        VoucherLink.RESET;
        VoucherLink.SETRANGE(VoucherLink."Entry No.", pTransClient."Provider Entry No.");
        VoucherLink.SETRANGE(VoucherLink."Auth. Code", pTransClient."Auth. Code");
        IF VoucherLink.FIND('-') THEN
            DeleteLinkVoucherFromVoucher(VoucherLink, 0);//Open static

        IF pNewState = 4 THEN BEGIN
            pTransClient.GET(pTransClient."Store No.", pTransClient."POS Terminal No.", pTransClient."Transaction No.", pTransClient."Line No.");
            pTransClient.VALIDATE(Status, pTransClient.Status::MatchReverse);
            pTransClient.MODIFY;
        END;//match reverse
    end;


    procedure CalcTransInPayment(pVoucher: Record "FSN POS Card Providers"; var recCount: Integer) TransInPaymentTmp: Decimal
    var
        VSClient: Record "FSN POS Card Prov. VS Customer";
    begin
        TransInPaymentTmp := 0;

        VSClient.RESET;
        VSClient.SETCURRENTKEY("Provider Entry No.", "Auth. Code");
        VSClient.SETRANGE(VSClient."Provider Entry No.", pVoucher."Entry No.");
        VSClient.SETRANGE(VSClient."Auth. Code", pVoucher."Auth. Code");
        VSClient.CALCSUMS(VSClient.Amount, VSClient."Amount Pending");

        //TransInPaymentTmp := VSClient.Amount;
        TransInPaymentTmp := VSClient.Amount - VSClient."Amount Pending";
        recCount := VSClient.COUNT;
    end;


    procedure Inherit(pFrom: Record "FSN POS Card Providers"; pTo: Record "FSN POS Card Providers")
    var
        lVoucher: Record "FSN POS Card Providers";
        lModVoucher: Record "FSN POS Card Providers";
    begin
        pFrom.GET(pFrom."Record Type", pFrom."Date Key", pFrom."Terminal ID", pFrom."Auth. Code", pFrom."Reference No.", pFrom."Amount Transaction");
        pTo.GET(pTo."Record Type", pTo."Date Key", pTo."Terminal ID", pTo."Auth. Code", pTo."Reference No.", pTo."Amount Transaction");

        IF pFrom.Close OR pTo.Close THEN
            EXIT;

        IF pFrom."Parent Entry No." > 0 THEN
            EXIT;

        pFrom.VALIDATE(Status, pFrom.Status::Inherit);
        pFrom."Parent Entry No." := pTo."Entry No.";
        pFrom."Parent Auth. Code" := pTo."Auth. Code";
        pFrom.MODIFY;

        pTo."Parent Entry No." := pTo."Entry No.";
        pTo."Parent Auth. Code" := pTo."Auth. Code";
        pTo.MODIFY;

        lVoucher.RESET;
        lVoucher.SETCURRENTKEY("Parent Entry No.", "Parent Auth. Code");
        lVoucher.SETRANGE(lVoucher."Parent Entry No.", pTo."Entry No.");
        lVoucher.SETRANGE(lVoucher."Parent Auth. Code", pTo."Parent Auth. Code");
        lVoucher.CALCSUMS("Amount Transaction", lVoucher."Amount Commission");

        lModVoucher.SETCURRENTKEY("Parent Entry No.", "Parent Auth. Code");
        lModVoucher.SETRANGE(lModVoucher."Parent Entry No.", pTo."Entry No.");
        lModVoucher.SETRANGE(lModVoucher."Parent Auth. Code", pTo."Parent Auth. Code");
        IF lModVoucher.FIND('-') THEN
            REPEAT
                lModVoucher."Parent Amt. Comission" := lVoucher."Amount Commission";
                lModVoucher."Parent Amount" := lVoucher."Amount Transaction";
                lModVoucher.MODIFY;
            UNTIL lModVoucher.NEXT = 0;
    end;


    procedure ApplyCancelVoucher(var pVoucher: Record "FSN POS Card Providers")
    begin
        DeleteLinkVoucherFromVoucher(pVoucher, 0);
    end;


    procedure ZeroPad(Str: Text[30]; Len: Integer): Text[30]
    var
        WrkString: Text[250];
    begin
        //ZeroPad
        WrkString := PADSTR('0', Len, '0') + Str;
        Str := COPYSTR(WrkString, STRLEN(WrkString) - Len + 1, Len);
        EXIT(Str);
    end;


    procedure VoucherCalcUsing(pVoucher: Record "FSN POS Card Providers"): Decimal
    var
        TransClient: Record "FSN POS Card Prov. VS Customer";
    begin
        TransClient.RESET;
        TransClient.SETCURRENTKEY("Provider Entry No.", "Auth. Code");

        IF pVoucher.Status = pVoucher.Status::Inherit THEN BEGIN
            TransClient.SETRANGE(TransClient."Provider Entry No.", pVoucher."Parent Entry No.");
            TransClient.SETRANGE(TransClient."Auth. Code", pVoucher."Parent Auth. Code");
        END ELSE BEGIN
            TransClient.SETRANGE(TransClient."Provider Entry No.", pVoucher."Entry No.");
            TransClient.SETRANGE(TransClient."Auth. Code", pVoucher."Auth. Code");
        END;
        TransClient.CALCSUMS(TransClient.Amount, TransClient."Amount Pending");
        EXIT(TransClient.Amount - TransClient."Amount Pending");
    end;


    procedure VoucherCalcTotalAmt(pVoucher: Record "FSN POS Card Providers"): Decimal
    var
        Vouchers: Record "FSN POS Card Providers";
    begin
        IF pVoucher."Parent Entry No." = 0 THEN
            EXIT(pVoucher."Amount Transaction");

        Vouchers.RESET;
        Vouchers.SETCURRENTKEY("Parent Entry No.", "Parent Auth. Code");
        Vouchers.SETRANGE(Vouchers."Parent Entry No.", pVoucher."Parent Entry No.");
        Vouchers.SETRANGE(Vouchers."Parent Auth. Code", pVoucher."Parent Auth. Code");
        Vouchers.CALCSUMS(Vouchers."Amount Transaction");
        EXIT(Vouchers."Amount Transaction")
    end;


    [EventSubscriber(ObjectType::Table, Database::"Vendor Ledger Entry", 'OnAfterCopyVendLedgerEntryFromGenJnlLine', '', true, true)]
    local procedure "Vendor Ledger Entry_OnAfterCopyVendLedgerEntryFromGenJnlLine"
    (
        var VendorLedgerEntry: Record "Vendor Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line"
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        VendorLedgerEntry."FSN Comment" := GenJournalLine.Comment;
        if (VendorLedgerEntry."Document Type"::Invoice = VendorLedgerEntry."Document Type") then begin
            RequestID := 'DTE-VENDLEDGENTRY';
            PosMenuLineTemp."Menu ID" := VendorLedgerEntry."Document No.";
            FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
            VendorLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
            VendorLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
        end;
        if VendorLedgerEntry."Source Code" = 'COMPRAS' then begin
            if VendorLedgerEntry."Document Type"::Invoice = VendorLedgerEntry."Document Type" then begin
                RequestID := 'DTE-VEND-INV-BC';
                PosMenuLineTemp."Menu ID" := VendorLedgerEntry."Document No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                VendorLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
                VendorLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
            end;
            if VendorLedgerEntry."Document Type"::"Credit Memo" = VendorLedgerEntry."Document Type" then begin
                RequestID := 'DTE-VEND-PCRM-BC';
                PosMenuLineTemp."Menu ID" := VendorLedgerEntry."Document No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                VendorLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
                VendorLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Table, Database::"Cust. Ledger Entry", 'OnAfterCopyCustLedgerEntryFromGenJnlLine', '', true, true)]
    local procedure "Cust. Ledger Entry_OnAfterCopyCustLedgerEntryFromGenJnlLine"
    (
        var CustLedgerEntry: Record "Cust. Ledger Entry";
        GenJournalLine: Record "Gen. Journal Line"
    )
    var
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line" temporary;
        Processed: Boolean;
        MsgResult: text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        CustLedgerEntry."FSN Comment" := GenJournalLine.Comment;
        if CustLedgerEntry."Source Code" = 'BACKOFFICE' then
            if (CustLedgerEntry."LSC Statement No." <> '') and (CustLedgerEntry."POS Store No." <> '') and (CustLedgerEntry."POS Terminal No." <> '') and (CustLedgerEntry."POS Transaction No." <> 0) then begin
                RequestID := 'DTE-CUSTLEDGENTRY';
                PosMenuLineTemp."Menu ID" := CustLedgerEntry."Document No.";
                PosMenuLineTemp."Current-MENU1" := CustLedgerEntry."LSC Statement No.";
                PosMenuLineTemp."Current-MENU2" := CustLedgerEntry."POS Store No.";
                PosMenuLineTemp."Current-MENU3" := CustLedgerEntry."POS Terminal No.";
                PosMenuLineTemp."POS Key Code" := CustLedgerEntry."POS Transaction No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                CustLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
                CustLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
            end;
        if CustLedgerEntry."Source Code" = 'VENTAS' then begin
            if CustLedgerEntry."Document Type"::Invoice = CustLedgerEntry."Document Type" then begin
                RequestID := 'DTE-CUST-INV-BC';
                PosMenuLineTemp."Menu ID" := CustLedgerEntry."Document No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                CustLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
                CustLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
            end;
            if CustLedgerEntry."Document Type"::"Credit Memo" = CustLedgerEntry."Document Type" then begin
                RequestID := 'DTE-CUST-SCRM-BC';
                PosMenuLineTemp."Menu ID" := CustLedgerEntry."Document No.";
                FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
                CustLedgerEntry."LSC Narration" := PosMenuLineTemp."Set Current-Input";
                CustLedgerEntry."FSN Comment" := PosMenuLineTemp."Current-Description";
            end;
        end;
    end;


    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Gen. Jnl.-Post Line", 'OnAfterInitGLEntry', '', true, true)]
    local procedure "Gen. Jnl.-Post Line_OnAfterInitGLEntry"
    (
        var GLEntry: Record "G/L Entry";
        GenJournalLine: Record "Gen. Journal Line";
        Amount: Decimal;
        AddCurrAmount: Decimal;
        UseAddCurrAmount: Boolean;
        var CurrencyFactor: Decimal
    )

    begin
        GLEntry."LSC Narration" := GenJournalLine.Comment;
    end;

    [EventSubscriber(ObjectType::Table, Database::"Report Selections", 'OnBeforePrintDocument', '', true, true)]
    local procedure "Report Selections_OnBeforePrintDocument"
        (
            TempReportSelections: Record "Report Selections";
            IsGUI: Boolean;
            RecVarToPrint: Variant;
            var IsHandled: Boolean
        )
    var
        payment: Page 256;
    begin

        if TempReportSelections."Report ID" = 1401 then begin
            REPORT.RunModal(50007, IsGUI, false, RecVarToPrint);
            IsHandled := true;
        end;
    end;


}

