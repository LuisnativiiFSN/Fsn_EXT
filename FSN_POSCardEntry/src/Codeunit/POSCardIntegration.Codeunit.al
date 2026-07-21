codeunit 50036 "FSN POS Card Integration"
{
    trigger OnRun()
    begin
    end;

    var
        gPlazo: Integer;
        gDateContext: Date;
        gCommand: Text[30];
        gDataEMV: Text;
        gDataBAN: Text;
        gCard: Text;
        gDataPin: Text;
        gDataPosEntryMode: Text;
        gDataSeqNo: Text;
        POSFunctions: Codeunit "LSC POS Functions";
        POSGUI: Codeunit "LSC POS GUI";
        DataCnn: Codeunit "FSN Card External Conextion";
        BOUTIL: Codeunit "LSC BO Utils";
        POSCardRequestEntry: Record "FSN POS Card Request Entry";
        POSTransaction: Record "LSC POS Transaction";
        POSMenuLineTmp: Record "LSC POS Menu Line" temporary;
        POSCardEntry: Record "LSC POS Card Entry";
        POSSession: Codeunit "LSC POS Session";
        POSPrintUtil: Codeunit "LSC POS Print Utility";
        POScardExtConextion: Codeunit "FSN Card External Conextion";
        BINList: Record "FSN BIN Bank";
        RetailSetup: Record "LSC Retail Setup";
        GlobalsFSNParameters: Record "FSN Parameter";
        POSTransLine: Record "LSC POS Trans. Line";
        TenderTypeSetup: Record "LSC Tender Type Setup";
        FSNParameter: Record "FSN Parameter";
        Text002: Label 'Transaction already exists No. Authorization %1';
        Text003: Label 'Tender type to be function Card';
        Text004: Label 'Record contains authorization No.%1';
        Text007: Label 'Cant be empty';
        Text009: Label 'Amount must be higth for zero';
        Text011: Label 'Terminal %1 is not configured for Kin POS.\Buy manual';
        Text012: Label 'Pay denegated. %1';
        Text013: Label 'Connection fail';
        Text014: Label 'Buy tipo is not valid!';
        Text015: Label 'Parameters not exists for manual mode';
        Text017: Label 'BIN %2 is not registered for use Tender Type %1';
        Text019: Label 'DUI is required';
        Text020: Label 'Tender Type %1 not allowed for BIN %2';
        Text022: Label 'Remaining (%1) is lower to solicitado (%2)';
        Text024: Label 'Transaction is voided, cant be voucher re used';
        Text027: Label 'For security cant be re use voucher in the same order.\Steps solution: \1)Create new order \2)Cancel complete the current order.';
        Text028: Label 'The order original %1 (%2) isnt finalized.\Steps solutions: \1)For security Cancel order %1 (%2) \2)Try transaction';

    //MANUAL
    procedure TestRequireFields(pRec: Record "LSC POS Card Entry"; pLevel: Integer)
    var
        _NumDecrypt: Text[150];
        _Int: Integer;
        _TextEval: Text[5];
    begin
        pRec.TESTFIELD(pRec."FSN Bank Name");
        _NumDecrypt := POScardExtConextion.DecryptCardNumber(pRec."EFT Additional ID", pRec."Receipt No.");
        IF _NumDecrypt = '' THEN
            pRec.FIELDERROR(pRec."Card Number", Text007);

        pRec.TESTFIELD(pRec."Expiry Date");
        POSTransLine.GET(pRec."Receipt No.", pRec."Line No.");
        POSTransLine.TESTFIELD(POSTransLine."Entry Status", POSTransLine."Entry Status"::" ");
        TenderTypeSetup.GET(POSTransLine.Number);
        IF TenderTypeSetup."FSN Function in CC" <> TenderTypeSetup."FSN Function in CC"::Card THEN
            ERROR(Text003);

        IF pLevel > 1 THEN BEGIN
            ConvertLastDateToParameter(ConvertLastDateFromParameter(pRec."Expiry Date"));

            //pRec.TESTFIELD(pRec."FSN CVV");//2706
            pRec.TESTFIELD(pRec.Amount);
            IF pRec.Amount <= 0 THEN
                ERROR(Text009);

            IF NOT POSTransLine.GET(pRec."Receipt No.", 36) THEN
                ERROR(Text019);

            IF POSTransLine."Entry Status" <> 0 THEN
                ERROR(Text019);

            IF pRec."Auth.code" <> '' THEN
                ERROR(STRSUBSTNO(Text004, pRec."Auth.code"));

            IF pRec."Authorisation Ok" AND (pRec."Auth.code" <> '') THEN
                ERROR(STRSUBSTNO(Text002, pRec."Auth.code"));

            IF TenderTypeSetup."FSN Used By Specific BIN" THEN BEGIN
                IF NOT BINList.GET(pRec."FSN BIN No.") THEN
                    ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, pRec."FSN BIN No."))
                ELSE
                    IF BINList."Tender Type Default" <> pRec."Tender Type" THEN
                        ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, pRec."FSN BIN No."));
            END ELSE BEGIN
                IF BINList.GET(pRec."FSN BIN No.") AND (BINList."Tender Type Default" <> '') THEN
                    IF BINList."Tender Type Default" <> pRec."Tender Type" THEN
                        ERROR(STRSUBSTNO(Text020, TenderTypeSetup.Description, pRec."FSN BIN No."));
            END;
        END;
    end;

    //MANUAL
    procedure ConvertLastDateToParameter(pLastCardDate: Text[5]): Text[5]
    var
        _Int: Integer;
        LSCPosCard: Record "LSC POS Card Entry";
    begin
        IF (STRPOS(pLastCardDate, '/') = 0) THEN begin
            pLastCardDate := CopyStr(pLastCardDate, 1, 2) + '/' + CopyStr(pLastCardDate, 3, 4);
            IF (STRPOS(pLastCardDate, '/') = 0) OR (STRLEN(pLastCardDate) <> 5) THEN
                ERROR(Text011, LSCPosCard.FIELDCAPTION("Expiry Date"));
        end;

        IF (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 1, 1))) OR (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 2, 1))) OR
          (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 4, 1))) OR (NOT EVALUATE(_Int, COPYSTR(pLastCardDate, 5, 1))) THEN
            ERROR(Text011, LSCPosCard.FIELDCAPTION("Expiry Date"));

        EVALUATE(_Int, COPYSTR(pLastCardDate, 1, 2));

        IF (_Int > 12) OR (_Int < 0) THEN
            ERROR(Text012, LSCPosCard.FIELDCAPTION("Expiry Date"));
        EVALUATE(_Int, COPYSTR(pLastCardDate, 4, 2));
        _Int += 2000;

        IF (_Int > 2099) OR (_Int < 2000) THEN
            ERROR(Text013, LSCPosCard.FIELDCAPTION("Expiry Date"));

        EXIT(COPYSTR(pLastCardDate, 4, 2) + COPYSTR(pLastCardDate, 1, 2));
    end;
    //MANUAL
    procedure ConvertLastDateFromParameter(pLastCardDate: Text[5]): Text[5]
    begin
        IF STRLEN(pLastCardDate) <> 4 THEN
            EXIT(pLastCardDate);

        EXIT(COPYSTR(pLastCardDate, 3, 2) + '/' + COPYSTR(pLastCardDate, 1, 2));
    end;

    //MANUAL
    procedure SetGlobalCommandInt(pOption: Integer)
    begin
        gCommand := '';
        CASE pOption OF
            0:
                gCommand := 'MANCOMPRANOR';
            1:
                gCommand := 'MANCOMPRAMIL';
            2:
                gCommand := 'MANCOMPRAPLA';
        END;

        IF gCommand = '' THEN
            ERROR(STRSUBSTNO(Text004, FORMAT(pOption)));
    end;

    //MANUAL
    procedure SetGlobalCommandManual(pCommand: Text[30])
    begin
        gCommand := pCommand;
    end;

    //MANUAL
    procedure SetGlobalDateContext(pDate: Date)
    begin
        gDateContext := pDate;
    end;

    //MANUAL
    procedure SetGlobalPlazoInt(pPlazo: Integer)
    begin
        gPlazo := pPlazo;
    end;

    //MANUAL
    procedure ValildateManualRequest(pRec: Record "LSC POS Card Entry"; var pLinkEntryNo: Integer; pEntityName: Text[50]): Boolean
    var
        CardInterface: Text[150];
        AmountInput: Text[30];
        pKey: Text;
        POSRequestReturn: Record "FSN POS Card Request Entry";
        lText011: Label 'Buy term require amount higher to $%1';
        lText013: Label 'BIN %1 have block. %2';
    begin
        RetailSetup.GET();

        IF BINList.GET(pRec."FSN BIN No.") AND (BINList."Restriction Type" = BINList."Restriction Type"::"Blocked In PinPad") then
            Error(STRSUBSTNO(lText013, pRec."FSN BIN No.", BINList."POS Message Restriction"));
        if not IsManualSetup(GlobalsFSNParameters) then
            Error(Text015);

        pLinkEntryNo := 0;
        if POSSESSION.GetValue('SALESCCPROCESSCUS') <> '' then begin
            CardInterface := pRec."EFT Additional ID";
        end else
            CardInterface := POScardExtConextion.DecryptCardNumber(pRec."EFT Additional ID", pRec."Receipt No.");
        AmountInput := DataCnn.GetTextInput(pRec.Amount);
        IF gCommand = 'MANCOMPRAPLA' THEN BEGIN
            IF pRec.Amount < GlobalsFSNParameters."Limit Term 1" THEN
                ERROR(STRSUBSTNO(lText011, GlobalsFSNParameters."Limit Term 1"));
        END;

        POSCardRequestEntry.RESET;
        POSCardRequestEntry.SETCURRENTKEY("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Receipt No.", pRec."Receipt No.");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Line No.", pRec."Line No.");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Cast Last Numbers", COPYSTR(CardInterface, STRLEN(CardInterface) - 3, STRLEN(CardInterface)));
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Enter Input", AmountInput);
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Response Web Ok", TRUE);
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Date Key", gDateContext);
        IF POSCardRequestEntry.FINDFIRST THEN BEGIN
            IF gCommand = 'MANCONMILLA' THEN
                EXIT(FALSE);

            POSRequestReturn.SETCURRENTKEY("Response Web Ok", "Void Number");
            POSRequestReturn.SETRANGE(POSRequestReturn."Response Web Ok", TRUE);
            POSRequestReturn.SETRANGE(POSRequestReturn."Void Number", POSCardRequestEntry."Entry No.");
            POSRequestReturn.SETRANGE(POSRequestReturn."Void Date Key", POSCardRequestEntry."Date Key");
            POSRequestReturn.SETRANGE(POSRequestReturn."Void Dist. Location", POSCardRequestEntry."Distribution Location");
            IF NOT POSRequestReturn.FINDFIRST THEN BEGIN

                pRec."Authorisation Ok" := POSCardRequestEntry."Response Web Ok";
                pRec."Auth.code" := POSCardRequestEntry."Authorization Code";
                pRec."EFT POS Terminal No." := RetailSetup."Distribution Location";

                IF pRec."Authorisation Ok" THEN BEGIN

                    pKey := BOUTIL.CombineValue(5, FORMAT(POSCardRequestEntry."Entry No."), FORMAT(DATE2DMY(gDateContext, 1)), FORMAT(DATE2DMY(gDateContext, 2))
                                              , FORMAT(DATE2DMY(gDateContext, 3)), POSCardRequestEntry."Distribution Location");
                    pRec."FSN Bank Name" := COPYSTR(pKey, 1, 50);
                    pRec."Auth.code" := POSCardRequestEntry."Trans Authorization";
                    pRec."EFT Terminal ID" := POSCardRequestEntry."Terminal ID";
                    pRec."EFT Trans. No." := COPYSTR(POSCardRequestEntry."Trans Reference", 1, MAXSTRLEN(pRec."EFT Trans. No."));
                    pRec."FSN Points/Terms" := '';
                    IF (POSCardRequestEntry.Command = 'MANCOMPRAMIL') THEN
                        pRec."FSN Points/Terms" := POSCardRequestEntry.Points
                    ELSE
                        IF (POSCardRequestEntry.Command = 'MANCOMPRAPLA') THEN
                            pRec."FSN Points/Terms" := POSCardRequestEntry.Plazo;

                    pRec."EFT Device Name" := POSCardRequestEntry.Command;
                    pRec.Message := POSCardRequestEntry.Command;
                    pRec.MODIFY;
                END;
                EXIT(FALSE);
            END;
        END;
        POSCardRequestEntry.INIT();
        POSCardRequestEntry."Date Key" := gDateContext;
        POSCardRequestEntry."Distribution Location" := RetailSetup."Distribution Location";
        POSCardRequestEntry.VALIDATE(POSCardRequestEntry."Entry No.");
        POSCardRequestEntry."Receipt ID" := POSFunctions.ZeroPad(FORMAT(POSCardRequestEntry."Entry No."), 6);
        POSCardRequestEntry."Send Audit No" := POSFunctions.ZeroPad(FORMAT(POSCardRequestEntry."Entry No."), 6);
        POSCardRequestEntry."Entity Name" := pEntityName;
        POSCardRequestEntry."Type Request" := POSCardRequestEntry."Type Request"::Web;
        POSCardRequestEntry."Cast Last Numbers" := COPYSTR(CardInterface, STRLEN(CardInterface) - 3, STRLEN(CardInterface));
        POSCardRequestEntry.BIN := COPYSTR(CardInterface, 1, 6);
        POSCardRequestEntry."Card Last Date" := pRec."Expiry Date";
        POSCardRequestEntry."CVV" := pRec."FSN CVV";
        POSCardRequestEntry."Bank Name" := pRec."FSN Bank Name";
        POSCardRequestEntry."Receipt No." := pRec."Receipt No.";
        POSCardRequestEntry."Line No." := pRec."Line No.";
        POSCardRequestEntry."Enter Input" := AmountInput;
        POSCardRequestEntry."Tender Type" := pRec."Tender Type";
        POSCardRequestEntry."Retailer ID" := GlobalsFSNParameters."Value Text 1";
        POSCardRequestEntry."Terminal ID" := GlobalsFSNParameters."Value Text 2";
        POSCardRequestEntry.User := USERID;
        POSTransaction.GET(pRec."Receipt No.");
        POSCardRequestEntry."Store No." := pRec."Store No.";
        POSCardRequestEntry."Customer No." := POSTransaction."Customer No.";
        POSCardRequestEntry.Date := CURRENTDATETIME;
        POSCardRequestEntry."Entry Mode" := '012';
        POSCardRequestEntry.Command := gCommand;
        POSCardRequestEntry."Card Filter" := CardInterface;
        POSCardRequestEntry."Amount Input" := POSCardRequestEntry."Enter Input";
        IF gCommand = 'MANCOMPRAPLA' THEN
            IF STRLEN(FORMAT(gPlazo)) = 1 THEN
                POSCardRequestEntry.Plazo := '0' + FORMAT(gPlazo)
            ELSE
                POSCardRequestEntry.Plazo := FORMAT(gPlazo);

        POSMenuLineTmp.RESET;
        POSMenuLineTmp.DELETEALL;
        CLEAR(POSMenuLineTmp);
        POSMenuLineTmp.INIT();

        POSCardRequestEntry.INSERT(TRUE);

        pLinkEntryNo := POSCardRequestEntry."Entry No.";
        EXIT(pLinkEntryNo <> 0);
    end;

    //MANUAL
    procedure ValidateVoidRequest(pRec: Record "FSN POS Card Request Entry"; var pLinkEntryNo: Integer; var pDate: Date): Boolean
    begin
        RetailSetup.GET();
        GlobalsFSNParameters.GET('KINPOS', RetailSetup."Distribution Location");

        POSCardRequestEntry.RESET;
        POSCardRequestEntry.SETCURRENTKEY("Response Web Ok", "Void Number");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Response Web Ok", TRUE);
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Void Number", pRec."Entry No.");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Void Date Key", pRec."Date Key");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Void Dist. Location", pRec."Distribution Location");
        IF POSCardRequestEntry.FINDFIRST THEN
            EXIT(FALSE);

        POSCardRequestEntry := pRec;
        POSCardRequestEntry."Date Key" := gDateContext;
        POSCardRequestEntry."Distribution Location" := RetailSetup."Distribution Location";
        POSCardRequestEntry.VALIDATE("Entry No.");
        POSCardRequestEntry."Receipt ID" := POSFunctions.ZeroPad(FORMAT(POSCardRequestEntry."Entry No."), 6);
        POSCardRequestEntry."Send Audit No" := POSFunctions.ZeroPad(POSCardRequestEntry."Send Audit No", 6);
        POSCardRequestEntry.Date := CURRENTDATETIME;
        POSCardRequestEntry.User := USERID;
        POSCardRequestEntry."Authorization Code" := '';
        POSCardRequestEntry."Response Web Ok" := FALSE;
        POSCardRequestEntry.Command := pRec.Command + 'A';
        POSCardRequestEntry."Amount Input" := '';
        POSCardRequestEntry."Entry Mode" := '071';
        POSCardRequestEntry."Terminal ID" := pRec."Terminal ID";
        POSCardRequestEntry."Trans Time" := '';
        POSCardRequestEntry."Trans Date" := '';
        POSCardRequestEntry."Trans Reference" := '';
        POSCardRequestEntry."Trans Authorization" := '';
        POSCardRequestEntry."Trans Tipo Mssg" := '';
        POSCardRequestEntry."Void Number" := pRec."Entry No.";
        POSCardRequestEntry."Void Date Key" := pRec."Date Key";//WVILLALTA24ENE2020-
        POSCardRequestEntry."Void Dist. Location" := pRec."Distribution Location";//WVILLALTA24ENE2020+
        POSCardRequestEntry.INSERT(TRUE);
        pLinkEntryNo := POSCardRequestEntry."Entry No.";
        pDate := POSCardRequestEntry."Date Key";
        EXIT(pLinkEntryNo <> 0);
    end;
    //MANUAL
    procedure SendRequest(pLinkNo: Integer; pRec: Record "LSC POS Card Entry"; pPlazo: Integer)
    var
        _LastDate: Text[4];
        CardInterface: Text[150];
        AmountInput: Text[30];
    begin
        RetailSetup.GET();
        POSCardRequestEntry.GET(pLinkNo, gDateContext, RetailSetup."Distribution Location");
        CardInterface := POScardExtConextion.DecryptCardNumber(pRec."EFT Additional ID", pRec."Receipt No.");
        AmountInput := DataCnn.GetTextInput(pRec.Amount);

        IF GlobalsFSNParameters.Grupo = 'KINPOSBAC' THEN BEGIN //Different device
            IF gCommand = 'MANCONMILLA' THEN
                CheckPoinsBac(pLinkNo, pRec, CardInterface)
            ELSE
                SendDataBac(pLinkNo, pRec, pPlazo, CardInterface);
            EXIT;
        END;

        POSMenuLineTmp.Command := 'KINPOS_SALE';
        POSMenuLineTmp.Parameter := gCommand;
        POSMenuLineTmp."Post Parameter" := CardInterface;
        POSMenuLineTmp."Current-INPUT" := AmountInput;
        POSMenuLineTmp."Current-LINE" := pLinkNo;
        POSMenuLineTmp."Glyph Text" := POSCardRequestEntry."Send Audit No";
        POSMenuLineTmp."Current-STATE" := POSCardRequestEntry."Card Last Date";
        POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
        POSMenuLineTmp."Primary Key" := POSCardRequestEntry."Terminal ID";
        POSMenuLineTmp.Description := POSCardRequestEntry."Retailer ID";
        POSMenuLineTmp."Current-RECEIPT" := POSCardRequestEntry."Receipt ID";
        POSMenuLineTmp."Current-SALESORDER" := POSCardRequestEntry.CVV;
        POSMenuLineTmp."Current-GUEST" := 0;
        if POSMenuLineTmp.Parameter = 'MANCONMILLA' then
            POSMenuLineTmp."Current-GUEST" := 2;
        POSMenuLineTmp."POS Help ID" := POSCardRequestEntry."Cast Last Numbers";
        POSMenuLineTmp."Current-UOM" := POSCardRequestEntry.BIN;
        POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);
        POSMenuLineTmp."Data ID" := pRec."Receipt No.";
        POSMenuLineTmp."POS Key Code" := POSCardRequestEntry."Entry No.";
        POSMenuLineTmp.INSERT;
        COMMIT;
        DataCnn.InitGlobalsFSNParameters(GlobalsFSNParameters);
        DataCnn.RUN(POSMenuLineTmp);
    end;
    //MANUAL
    procedure SendVoidRequest(OldRec: Record "FSN POS Card Request Entry"; NewRec: Record "FSN POS Card Request Entry")
    var
        _LastDate: Text[4];
        CardInterface: Text[150];
        AmountInput: Text[30];
        POSDataTemporary: Record "FSN POS Data Temporary";
    begin
        POSMenuLineTmp.RESET;
        POSMenuLineTmp.DELETEALL;
        CLEAR(POSMenuLineTmp);
        POSDataTemporary.GET(POSDataTemporary."Type Phrase"::"Card Request Entry", POSCardRequestEntry."Void Number", POSCardRequestEntry."Void Date Key", POSCardRequestEntry."Void Dist. Location");
        CardInterface := Decrypt(POSDataTemporary.Value); //cLSExternalFunc.Decrypt(POSDataTemporary.Value);

        POSMenuLineTmp.INIT();
        POSMenuLineTmp.Command := 'KINPOS_SALE';
        POSMenuLineTmp.Parameter := gCommand;
        POSMenuLineTmp."Post Parameter" := CardInterface;
        POSMenuLineTmp."Current-INPUT" := OldRec."Enter Input";
        POSMenuLineTmp."Current-LINE" := NewRec."Entry No.";
        POSMenuLineTmp."Glyph Text" := NewRec."Send Audit No";
        POSMenuLineTmp."Current-STATE" := OldRec."Card Last Date";
        POSMenuLineTmp."Current-POSID" := OldRec."Distribution Location";
        POSMenuLineTmp."Primary Key" := OldRec."Terminal ID";
        POSMenuLineTmp.Description := OldRec."Retailer ID";
        POSMenuLineTmp."Current-RECEIPT" := OldRec."Receipt ID";
        POSMenuLineTmp."Current-SALESORDER" := OldRec.CVV;
        POSMenuLineTmp."Current-GUEST" := 0;
        POSMenuLineTmp."POS Help ID" := OldRec."Cast Last Numbers";
        POSMenuLineTmp."Current-UOM" := OldRec.BIN;
        POSMenuLineTmp.XPos := DATE2DMY(NewRec."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(NewRec."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(NewRec."Date Key", 3);
        POSMenuLineTmp."Data ID" := OldRec."Receipt No.";
        //POSMenuLineTmp."Last-LINE" := OldRec."Line No.";
        POSMenuLineTmp."POS Key Code" := NewRec."Entry No.";
        POSMenuLineTmp."Current-MENU" := OldRec."Trans Reference";
        POSMenuLineTmp."Current-MENU1" := OldRec."Trans Authorization";
        POSMenuLineTmp."Current-MENU2" := OldRec."Trans Time";
        POSMenuLineTmp."Current-MENU3" := OldRec."Trans Date";
        POSMenuLineTmp.INSERT;
        COMMIT;
        DataCnn.InitGlobalsFSNParameters(GlobalsFSNParameters);
        DataCnn.RUN(POSMenuLineTmp);
    end;

    //MANUAL
    procedure GetIntCommand(pCommand: Text[50]) ReturnInt: Integer
    begin
        ReturnInt := 0;
        CASE pCommand OF
            'MANCOMPRANOR':
                ReturnInt := 0;
            'MANCOMPRAMIL':
                ReturnInt := 1;
            'MANCOMPRAPLA':
                ReturnInt := 2;
            'MANCOMPRANORA',
          'MANCOMPRAMILA',
          'MANCOMPRAPLAA':
                ReturnInt := 3;
        END;
    end;
    //MANUAL
    procedure CreateTransacInherit(pRequestEntry: Record "FSN POS Card Request Entry"; pRec: Record "LSC POS Card Entry"; pAmountOrig: Decimal; var pTextError: Text): Boolean
    var
        RequestInherit: Record "FSN POS Card Request Inherit";
        RequestIsReturn: Record "FSN POS Card Request Entry";
        DelOrder: Record "LSC Delivery Order";
        PostDelOrder: Record "LSC Posted Delivery Order";
        TransHdr: Record "LSC Transaction Header";
        POSLine: Record "LSC POS Trans. Line";
        Balance: Decimal;
        _InheritExists: Boolean;
        _AmtInReturn: Decimal;
        _Int: Integer;
        _Remaining: Decimal;
        Text1601: Label 'NO SE HA REALIZADO DEVOLUCION';
        BaseSum_l: Decimal;
    begin
        RequestIsReturn.RESET;
        RequestIsReturn.SETCURRENTKEY("Response Web Ok", "Void Number");
        RequestIsReturn.SETRANGE(RequestIsReturn."Response Web Ok", TRUE);
        RequestIsReturn.SETRANGE(RequestIsReturn."Void Number", pRequestEntry."Entry No.");
        RequestIsReturn.SETRANGE(RequestIsReturn."Void Date Key", pRequestEntry."Date Key");
        RequestIsReturn.SETRANGE(RequestIsReturn."Distribution Location", pRequestEntry."Distribution Location");
        IF RequestIsReturn.FINDFIRST THEN BEGIN
            pTextError := STRSUBSTNO(Text024);
            EXIT(FALSE);
        END;

        IF pRec."Receipt No." = pRequestEntry."Receipt No." THEN
            ERROR(Text027);

        IF DelOrder.GET(pRequestEntry."Receipt No.") THEN
            ERROR(STRSUBSTNO(Text028, DelOrder."Order No.", DelOrder."Phone No."));

        IF RequestInherit.GET(pRequestEntry."Entry No.", pRequestEntry."Date Key", pRequestEntry."Distribution Location"
            , pRec."Receipt No.", pRec."Line No.") THEN
            EXIT(TRUE);

        _Remaining := CheckRemaining(pRequestEntry);

        EVALUATE(BaseSum_l, pRequestEntry."Amount Input");
        IF STRPOS(pRequestEntry."Amount Input", '.') = 0 THEN
            BaseSum_l := BaseSum_l / 100;

        IF (_Remaining < pRec.Amount) THEN BEGIN
            pTextError := STRSUBSTNO(Text022, FORMAT(_Remaining), FORMAT(pRec.Amount));
            EXIT(FALSE);
        END;

        RequestInherit.INIT;
        RequestInherit."Entry No." := pRequestEntry."Entry No.";
        RequestInherit."Date key" := pRequestEntry."Date Key";
        RequestInherit."Distribution Location" := pRequestEntry."Distribution Location";
        RequestInherit."Receipt No. Inherit" := pRec."Receipt No.";
        RequestInherit."Line In Receipt" := pRec."Line No.";
        RequestInherit."New Date Key" := TODAY;
        RequestInherit."Store No. Inherit" := pRec."Store No.";
        RequestInherit."Amount Inherit" := pRec.Amount;
        RequestInherit."Original Amt. Inherit" := pAmountOrig;
        RequestInherit."Entry Status" := RequestInherit."Entry Status"::Used;
        IF _InheritExists THEN
            RequestInherit.MODIFY(TRUE)
        ELSE
            RequestInherit.INSERT(TRUE);

        EXIT(TRUE);

    end;

    //MANUAL
    procedure CheckRemaining(pRec: Record "FSN POS Card Request Entry"): Decimal
    var
        TransHdr: Record "LSC Transaction Header";
        TransPayment: Record "LSC Trans. Payment Entry";
        DelOrder: Record "LSC Delivery Order";
        PostDelOrder: Record "LSC Posted Delivery Order";
        RequestInherit: Record "FSN POS Card Request Inherit";
        RequestInheritS: Record "FSN POS Card Request Inherit";
        POSLine: Record "LSC POS Trans. Line";
        PosTransac: Codeunit "LSC POS Transaction";
        PosCardEntry: Record "LSC POS Card Entry";
        Sums_l: Decimal;
        BaseSum_l: Decimal;
        ReturnSum_l: Decimal;
        UsedSum_l: Decimal;
        _InheritExists: Boolean;
        Amount: Decimal;
        TAmount: Decimal;
        PAmount: Decimal;

    begin
        CLEAR(Sums_l);
        CLEAR(BaseSum_l);
        CLEAR(ReturnSum_l);
        CLEAR(UsedSum_l);
        IF pRec."Amount Input" = '' THEN
            pRec.FIELDERROR(pRec."Amount Input", STRSUBSTNO(Text011, FORMAT(0)));


        EVALUATE(BaseSum_l, pRec."Amount Input");
        IF STRPOS(pRec."Amount Input", '.') = 0 THEN
            BaseSum_l := BaseSum_l / 100;

        IF DelOrder.GET(pRec."Receipt No.") THEN BEGIN//if order exists, logical here
        END;

        TransHdr.RESET;
        TransHdr.SETRANGE(TransHdr."Receipt No.", pRec."Receipt No.");
        IF TransHdr.FINDFIRST AND (TransHdr."Entry Status" = 0) THEN BEGIN
            UsedSum_l := BaseSum_l;
        END;

        RequestInherit.RESET;
        RequestInherit.SETCURRENTKEY("Entry No.", "Date key", "Distribution Location", "Receipt No. Inherit", "Line In Receipt");
        RequestInherit.SETRANGE(RequestInherit."Entry No.", pRec."Entry No.");
        RequestInherit.SETRANGE(RequestInherit."Date key", pRec."Date Key");
        RequestInherit.SETRANGE(RequestInherit."Distribution Location", pRec."Distribution Location");
        IF RequestInherit.FIND('-') THEN
            REPEAT
                _InheritExists := FALSE;
                IF RequestInherit."Entry Status" = RequestInherit."Entry Status"::Used THEN BEGIN
                    _InheritExists := PostDelOrder.GET(RequestInherit."Receipt No. Inherit");

                    IF _InheritExists THEN BEGIN
                        TransHdr.RESET;
                        TransHdr.SETCURRENTKEY("Receipt No.", Date);
                        TransHdr.SETRANGE(TransHdr."Receipt No.", RequestInherit."Receipt No. Inherit");
                        IF TransHdr.FINDFIRST THEN BEGIN
                            IF TransHdr."Entry Status" <> 0 THEN
                                RequestInherit."Entry Status" := RequestInherit."Entry Status"::Void;
                        END;

                    END ELSE BEGIN

                        IF NOT POSLine.GET(RequestInherit."Receipt No. Inherit", RequestInherit."Line In Receipt") THEN
                            RequestInherit."Entry Status" := RequestInherit."Entry Status"::Void
                        ELSE
                            IF POSLine."Entry Status" <> 0 THEN
                                RequestInherit."Entry Status" := RequestInherit."Entry Status"::Void;
                    END;

                    IF RequestInherit."Entry Status" = RequestInherit."Entry Status"::Void THEN
                        RequestInherit.MODIFY(TRUE);
                END;
            UNTIL RequestInherit.NEXT = 0;

        RequestInherit.SETRANGE(RequestInherit."Entry Status", RequestInherit."Entry Status"::Used);
        RequestInherit.CALCSUMS(RequestInherit."Amount Inherit");
        Sums_l := UsedSum_l + RequestInherit."Amount Inherit";

        RequestInherit.SETRANGE(RequestInherit."Entry Status", RequestInherit."Entry Status"::Returned);
        RequestInherit.CALCSUMS(RequestInherit."Amount Inherit");
        Sums_l += RequestInherit."Amount Inherit" - ReturnSum_l;

        PAmount := BaseSum_l - Sums_l;
        if (PAmount > 0) and (PAmount <= BaseSum_l) then begin
            PosCardEntry.Reset();
            PosCardEntry.SetRange("Receipt No.", PosTransac.GetReceiptNo());
            PosCardEntry.SetFilter("Res.code", '=%1', '');
            if PosCardEntry.FindFirst() then
                if PosCardEntry.Amount <= PAmount then
                    exit(PAmount);
        end;

        if (PAmount < BaseSum_l) then begin
            IF pRec."Distribution Location" in ['F20'] then begin
                if PAmount > 0.0 then
                    Amount := PAmount;

                RequestInheritS.RESET;
                RequestInheritS.SETCURRENTKEY("Entry No.", "Date key", "Distribution Location", "Receipt No. Inherit", "Line In Receipt");
                RequestInheritS.SETRANGE(RequestInheritS."Entry No.", pRec."Entry No.");
                RequestInheritS.SETRANGE(RequestInheritS."Date key", pRec."Date Key");
                RequestInheritS.SETRANGE(RequestInheritS."Distribution Location", pRec."Distribution Location");
                RequestInheritS.SetRange(RequestInheritS."Entry Status", RequestInherit."Entry Status"::Used);
                IF RequestInheritS.Find('-') then begin
                    repeat
                        Amount += Reutilizacion(RequestInheritS."Store No. Inherit", RequestInheritS."Receipt No. Inherit", RequestInheritS."Line In Receipt");
                    until RequestInheritS.Next() = 0;
                end else
                    Amount := Reutilizacion(pRec."Store No.", pRec."Receipt No.", pRec."Line No.");

                if Amount = 0 then begin
                    IF RequestInherit."Entry Status" = RequestInherit."Entry Status"::Void then begin
                        exit(BaseSum_l);
                    end;
                end else
                    Exit(Amount);
            end;
        end;
        exit(PAmount);
    end;

    procedure Reutilizacion(Store: Code[20]; Receipt: Code[20]; Line: Integer): Decimal
    var
        SqlConnection: DotNet SqlConnection;
        SqlCommand: DotNet SqlCommand;
        SqlDataReader: DotNet SqlDataReader;
        ConnectionString: Text[150];
        SqlString: Text;
        DisLocation: Record "LSC Distribution Location";
        lTextConn: Label 'Data Source=%1;Initial Catalog=%2;Integrated Security=false; User ID=%3;Password=%4;';
        lTextSimbol: Label '''''';
        Amount: Decimal;
        TAmount: Decimal;
        PAmount: Decimal;
        RequestInherit: Record "FSN POS Card Request Inherit";
        RequestEntry: Record "FSN POS Card Request Entry";
        DelOrder: Record "LSC Delivery Order";
        Tex160: Label 'The order %1 (%2) isnt finalized.\Steps solutions: \1)For security Cancel order %1 (%2) \2)Try transaction';
        VoidedLine: Record "LSC POS Voided Trans. Line";
        BaseSum_l: Decimal;
        _Int: Integer;
    begin
        Amount := 0.0;
        DisLocation.Reset();
        if DisLocation.GET(Store) then begin
            ConnectionString := STRSUBSTNO(lTextConn, DisLocation."Db Server Name", DisLocation."Db. Path && Name", DisLocation."User ID", DisLocation.Password);
            SqlConnection := SqlConnection.SqlConnection(ConnectionString);
            SqlString := 'SELECT f.Amount FROM' +
                        '[DBTIENDA].[fsn].[FASANI$LSC POS Card Entry]f JOIN ' +
                        ' [DBTIENDA].[fsn].[FASANI$LSC Transaction Header] t ' +
                        'ON f.[Receipt No_]=t.[Retrieved from Receipt No_]' +
                         'WHERE f.[Receipt No_] = ''' + Receipt + '''and f.[Line No_]= ''' + Format(Line) + '''';

            SqlConnection.Open();
            SqlCommand := SqlConnection.CreateCommand();
            SqlCommand.CommandText := SqlString;
            SqlDataReader := SqlCommand.ExecuteReader();
            IF SqlDataReader.Read() THEN
                Amount := SqlDataReader.GetDecimal(0);
            SqlConnection.Close();
        end;
        IF Amount = 0.0 then begin
            RequestInherit.Reset();
            RequestInherit.SetRange("Receipt No. Inherit", Receipt);
            RequestInherit.SetRange("Store No. Inherit", Store);
            IF RequestInherit.FindFirst() then begin
                if DelOrder.Get(RequestInherit."Receipt No. Inherit") then begin
                    ERROR(STRSUBSTNO(Tex160, DelOrder."Order No.", DelOrder."Phone No."));
                end;
            end;
            RequestEntry.Reset();
            RequestEntry.SetRange("Receipt No.", Receipt);
            RequestEntry.SetRange("Store No.", Store);
            RequestEntry.SetRange("Line No.", Line);
            IF RequestEntry.FindFirst() then begin
                EVALUATE(BaseSum_l, RequestEntry."Amount Input");
                IF STRPOS(RequestEntry."Amount Input", '.') = 0 THEN
                    BaseSum_l := BaseSum_l / 100;
            end;
            VoidedLine.Reset();
            VoidedLine.SetRange("Receipt No.", Receipt);
            VoidedLine.SetRange("Store No.", Store);
            VoidedLine.SetRange("Line No.", Line);
            VoidedLine.SetRange(Amount, BaseSum_l);
            IF VoidedLine.FindFirst() then begin
                exit(BaseSum_l);
            end;
        end else begin
            RequestInherit.Reset();
            RequestInherit.SetRange("Receipt No. Inherit", Receipt);
            RequestInherit.SetRange("Store No. Inherit", Store);
            IF RequestInherit.FindFirst() then begin
                RequestInherit."Entry Status" := RequestInherit."Entry Status"::Returned;
                RequestInherit."Amount Inherit" := 0.00;
                RequestInherit.Modify();
            end;
        end;
        exit(Amount);
    end;

    //MANUAL
    procedure SendDataBac(pLinkNo: Integer; pRec: Record "LSC POS Card Entry"; pPlazo: Integer; Number: Text[25])
    var
        /*[RunOnClient]
        cspRequest: DotNet EMVStreamRequest;*/
        xml: Text;
        amt: Text[50];
        terminal: Text[100];
        POSMenuLineTmp: Record "LSC POS Menu Line" temporary;
        ParameterSetup: Record "FSN Parameter";
        JObject: DotNet JObject;
        JToken: DotNet JToken;
        JArray: DotNet JArray;
        Txt1: Label 'Terms parameter is not configured or allowed.';
    begin
        //JNEHEMIAS050921-
        COMMIT;
        ParameterSetup.GET('KINPOSBAC', GlobalsFSNParameters.Codigo);
        ParameterSetup.TESTFIELD("Value Text 2");
        ParameterSetup.TESTFIELD(Activo);

        RetailSetup.GET();
        POSCardRequestEntry.GET(pLinkNo, gDateContext, RetailSetup."Distribution Location");
        /*
            CLEAR(cspRequest);
            cspRequest := cspRequest.EMVStreamRequest();
            CASE POSCardRequestEntry.Command OF
                'MANCOMPRANOR':
                    BEGIN
                        cspRequest.transactionType := 'SALE';
                        POSMenuLineTmp.Parameter := 'SALE';
                        terminal := ParameterSetup."Value Text 1";
                    END;
                'MANCOMPRAPLA':
                    BEGIN
                        cspRequest.transactionType := 'PAYMENT_PLAN';
                        cspRequest.paymentPlan('CR');
                        cspRequest.paymentPlanTerm(POSCardRequestEntry.Plazo);
                        POSMenuLineTmp.Parameter := 'PAYMENT_PLAN';
                        IF (ParameterSetup."String Parameters 1 Json" <> '') THEN BEGIN
                            JObject := JObject.JObject();
                            JObject := JObject.Parse(ParameterSetup."String Parameters 1 Json");
                            JArray := JObject.SelectToken('TERMS');
                            CASE POSCardRequestEntry.Plazo OF
                                '03':
                                    terminal := JArray.Item(0).ToString();
                                '06':
                                    terminal := JArray.Item(1).ToString();
                                '09':
                                    terminal := JArray.Item(2).ToString();
                                ELSE BEGIN
                                        CLEAR(cspRequest);
                                        MESSAGE(Txt1);
                                        EXIT;
                                    END;
                            END;
                        END ELSE BEGIN
                            CLEAR(cspRequest);
                            MESSAGE(Txt1);
                            EXIT;
                        END;
                    END;
                'MANCOMPRAMIL':
                    BEGIN
                        cspRequest.transactionType := 'POINTS';
                        cspRequest.pointsPlan('4'); //Standar
                        POSMenuLineTmp.Parameter := 'POINTS';
                        terminal := ParameterSetup."Value Text 2";
                    END;
            END;
            IF (terminal = '0') OR (terminal = '') THEN BEGIN
                CLEAR(cspRequest);
                MESSAGE(Txt1);
                EXIT;
            END;

            IF POSCardRequestEntry.Command = 'MANCOMPRAMIL' THEN
                amt := DELCHR(FORMAT(ROUND(pRec.Amount / 0.006, 1, '=')), '=', ',')
            ELSE
                amt := DELCHR(FORMAT(ROUND(pRec.Amount, 0.01)), '=', ',');

            cspRequest.totalAmount := amt;          //
            cspRequest.terminalId := terminal;
            cspRequest.invoice := POSCardRequestEntry."Receipt ID";
            cspRequest.accountNumber := Number;
            cspRequest.expirationDate := POSCardRequestEntry."Card Last Date";
            IF POSCardRequestEntry.Command <> 'MANCOMPRAMIL' THEN
                cspRequest.avsEntry := '0';

            xml := cspRequest.sendData();
            //MESSAGE(FORMAT(xml));
            POSMenuLineTmp.Command := 'BAC';
            POSMenuLineTmp."Current-RECEIPT" := pRec."Receipt No.";
            POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
            POSMenuLineTmp."Current-LINE" := POSCardRequestEntry."Entry No.";
            POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
            POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
            POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);
            POSMenuLineTmp."POS Help ID" := terminal;

            CLEAR(DataCnn);
            DataCnn.InitRequestGlobals('', '', xml, '', '', POSMenuLineTmp.Parameter);
            COMMIT;
            IF DataCnn.RUN(POSMenuLineTmp) THEN;
            *///REVISAR BAC
    end;

    //MANUAL
    procedure CheckPoinsBac(pEntryNo: Integer; pRec: Record "LSC POS Card Entry"; pCard: Text[25])
    var
        /*
        [RunOnClient]
        cspRequest: DotNet EMVStreamRequest;*/
        xml: Text;
        Text001: Label 'Points %1 equivalent to $ %2';
        Text002: Label 'Error Service';
        ParameterSetup: Record "FSN Parameter";
    begin

        COMMIT;

        RetailSetup.GET();
        POSCardRequestEntry.GET(pEntryNo, gDateContext, RetailSetup."Distribution Location");
        /*
        CLEAR(cspRequest);
        cspRequest := cspRequest.EMVStreamRequest();

        ParameterSetup.GET('KINPOSBAC', GlobalsFSNParameters.Codigo);
        ParameterSetup.TESTFIELD("Value Text 2");
        ParameterSetup.TESTFIELD(Activo);

        cspRequest.transactionType := 'POINTS_INQUIRY';
        cspRequest.terminalId := ParameterSetup."Value Text 2";
        cspRequest.invoice := POSCardRequestEntry."Receipt ID";
        cspRequest.accountNumber := pCard;
        cspRequest.expirationDate := POSCardRequestEntry."Card Last Date";
        cspRequest.pointsPlan('4');//Standar
        cspRequest.avsEntry := '0';
        xml := cspRequest.sendData();
        //MESSAGE(FORMAT(xml));

        POSMenuLineTmp.Command := 'BAC';
        POSMenuLineTmp.Parameter := 'POINTS_INQUIRY';
        POSMenuLineTmp."Current-RECEIPT" := pRec."Receipt No.";
        POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
        POSMenuLineTmp."Current-LINE" := POSCardRequestEntry."Entry No.";
        POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);
        POSMenuLineTmp."POS Help ID" := ParameterSetup."Value Text 2";

        CLEAR(DataCnn);
        DataCnn.InitRequestGlobals('', '', xml, '', '', POSMenuLineTmp.Parameter);
        COMMIT;
        IF DataCnn.RUN(POSMenuLineTmp) THEN;
        *///REVISAR BAC
    end;

    procedure ProcessMessageTrans(pEntryNo: Integer; pRec: Record "LSC POS Card Entry"): Text[250]
    var
        lText0: Label 'Transaccion%1';
        lText1: Label 'Error en transaccion %1';
    begin
        RetailSetup.Get();
        if IsManualSetup() then
            POSCardRequestEntry.Get(pEntryNo, Today, RetailSetup."Distribution Location")
        else
            POSCardRequestEntry.Get(pEntryNo, Today, RetailSetup."Distribution Location");

        if POSCardRequestEntry."Authorization Code" in ['OK', '00'] then
            exit(STRSUBSTNO(lText0, DataCnn.SRFGetErrorCodeText(POSCardRequestEntry."Authorization Code")))
        else
            exit(STRSUBSTNO(lText1, DataCnn.SRFGetErrorCodeText(POSCardRequestEntry."Authorization Code")));
    end;

    procedure ProcessMessagePoints(pEntryNo: Integer; pRec: Record "LSC POS Card Entry"): Text[250]
    var
        lText0: Label 'Points %1 , equivalent to $%2. (Transaction %3)';
        lText1: Label 'Cant be query points %1';
    begin
        RetailSetup.Get();
        if IsManualSetup() then
            POSCardRequestEntry.Get(pEntryNo, Today, RetailSetup."Distribution Location")
        else
            POSCardRequestEntry.Get(pEntryNo, Today, RetailSetup."Distribution Location");

        if POSCardRequestEntry."Authorization Code" in ['OK', '00'] then
            exit(STRSUBSTNO(lText0, GetDecimalFromText(POSCardRequestEntry.Points), GetDecimalFromText(POSCardRequestEntry."Amount Input"), FORMAT(POSCardRequestEntry."Entry No.")))
        else
            exit(STRSUBSTNO(lText1, DataCnn.SRFGetErrorCodeText(POSCardRequestEntry."Authorization Code")));
    end;
    //MANUAL
    procedure SendVoidRequestBac(OldRec: Record "FSN POS Card Request Entry"; NewRec: Record "FSN POS Card Request Entry")
    var
        /*[RunOnClient]
        cspRequest: DotNet EMVStreamRequest;*/
        xml: Text;
        ParameterSetup: Record "FSN Parameter";
    begin
        RetailSetup.GET();
        POSCardRequestEntry := NewRec;
        /*
        CLEAR(cspRequest);
        cspRequest := cspRequest.EMVStreamRequest();

        ParameterSetup.GET('KINPOSBAC', GlobalsFSNParameters.Codigo);
        ParameterSetup.TESTFIELD("Value Text 2");
        ParameterSetup.TESTFIELD(Activo);

        cspRequest.transactionType := 'VOID';
        cspRequest.terminalId := ParameterSetup."Value Text 2";
        cspRequest.authorizationNumber := OldRec."Trans Authorization";
        cspRequest.referenceNumber := OldRec."Trans Reference";
        cspRequest.systemTraceNumber := OldRec."Trans Audit No";
        xml := cspRequest.sendData();

        //MESSAGE(FORMAT(xml));

        POSMenuLineTmp.Command := 'BAC';
        POSMenuLineTmp.Parameter := 'VOID';
        POSMenuLineTmp."Current-RECEIPT" := OldRec."Receipt No.";
        POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
        POSMenuLineTmp."Current-LINE" := POSCardRequestEntry."Entry No.";
        POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);
        POSMenuLineTmp."POS Help ID" := GlobalsFSNParameters."Value Text 2";
        *///REVISAR BAC
        CLEAR(DataCnn);
        DataCnn.InitRequestGlobals('', '', xml, '', '', POSMenuLineTmp.Parameter, '', '', '');
        COMMIT;
        IF DataCnn.RUN(POSMenuLineTmp) THEN;
    end;
    //BOTH
    procedure ConvertCommandGeneric(pGenericInt: Integer; var pEntryMode: Text[10]): Text[50]
    var
        lCommand: Text[50];
    begin
        CASE pGenericInt OF
            1:
                BEGIN//Normal Buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRANOR';
                        'S', 'V':
                            lCommand := 'BANCOMPRANOR';
                        'I', 'C':
                            lCommand := 'EMVCOMPRANOR';
                    END;
                END;
            2:
                BEGIN//Points Query
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCONMILLA';
                        'S', 'V':
                            lCommand := 'BANCONMILLA';
                        'I', 'C':
                            lCommand := 'EMVCONMILLA';
                    END;
                END;
            3:
                BEGIN//Points Buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRAMIL';
                        'S', 'V':
                            lCommand := 'BANCOMPRAMIL';
                        'I', 'C':
                            lCommand := 'EMVCOMPRAMIL';
                    END;
                END;
            4:
                BEGIN//Void normal buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRANORA';
                        'S', 'V':
                            lCommand := 'BANCOMPRANORA';
                        'I', 'C':
                            lCommand := 'EMVCOMPRANORA';
                    END;
                END;
            5:
                BEGIN//Void point buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRAMILA';
                        'S', 'V':
                            lCommand := 'BANCOMPRAMILA';
                        'I', 'C':
                            lCommand := 'EMVCOMPRAMILA';
                    END;
                END;
            6:
                BEGIN//Terms buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRAPLA';
                        'S', 'V':
                            lCommand := 'BANCOMPRAPLA';
                        'I', 'C':
                            lCommand := 'EMVCOMPRAPLA';
                    END;
                END;
            7:
                BEGIN//Terms void buy
                    CASE pEntryMode OF
                        'M':
                            lCommand := 'MANCOMPRAPLAA';
                        'S', 'V':
                            lCommand := 'BANCOMPRAPLAA';
                        'I', 'C':
                            lCommand := 'EMVCOMPRAPLAA';
                    END;
                END;
        END;
        EXIT(lCommand);
    end;

    //BOTH
    procedure ConvertModeNumber(pMode: Text[10]): Text[10]
    begin
        CASE pMode OF
            'M':
                EXIT('012');
            'S', 'V':
                EXIT('022');
            'I':
                EXIT('050');
            'C':
                EXIT('071');
        END;
    end;

    //BOTH
    procedure ConvertCommandToType(Command: Text[50]): Text[10]
    begin
        CASE Command OF
            'BANCHECKINN':
                BEGIN
                END;
            'BANCHECKINNA':
                BEGIN
                END;
            'BANCHECKOUT':
                BEGIN
                END;
            'BANCHECKOUTA':
                BEGIN
                END;
            'BANCOMPRADEV',
            'BANCOMPRAMILA',
            'BANCOMPRANORA',
            'BANCOMPRAPLAA',
            'EMVCOMPRANORA',
            'EMVCOMPRAMILA',
            'EMVCOMPRAPLAA',
            'MANCOMPRAMILA',
            'MANCOMPRANORA',
            'MANCOMPRAPLAA':
                BEGIN
                    EXIT('DEVOL');
                END;
            'BANCONMILLA',
            'MANCONMILLA',
            'EMVCONMILLA':
                BEGIN
                    EXIT('CONMILLA');
                END;
            'PUNTOS',
            'BANCOMPRAMIL',
            'MANCOMPRAMIL',
            'EMVCOMPRAMIL':
                BEGIN
                    EXIT('PUNTOS');
                END;
            '',
            'BANCOMPRANOR',
            'EMVCOMPRANOR',
            'MANCOMPRANOR':
                BEGIN
                    EXIT('NORMAL');
                END;
            'PLAZOS',
            'PLAZO',
            'BANCOMPRAPLA',
            'MANCOMPRAPLA',
            'EMVCOMPRAPLA':
                BEGIN
                    EXIT('PLAZOS');
                END;
            'EMVCHECKINN':
                BEGIN
                END;
            'EMVCHECKOUT':
                BEGIN
                END;
            'EMVCHECKOUTA':
                BEGIN
                END;
            'MANCHECKINN':
                BEGIN
                END;
            'MANCHECKOUT':
                BEGIN
                END;
            ELSE
                EXIT('NA');
        END;
    end;

    //BOTH
    procedure GenerateReceiptID(pEntry: Integer): Text[6]
    var
        POSFunctions: Codeunit "LSC POS Functions";
        _Code: Text;
    begin
        _Code := '';
        _Code := '1' + FORMAT(pEntry);
        _Code := POSFunctions.ZeroPad(_Code, 6);
        EXIT(_Code);
    end;

    //BOTH
    procedure TransferInfoToCardEntry(pFromCardRequestEntry: Record "FSN POS Card Request Entry"; pToCardEntry: Record "LSC POS Card Entry")
    var
        pKey: Text;
    begin
        pToCardEntry.Get(pToCardEntry."Store No.", pToCardEntry."POS Terminal No.", pToCardEntry."Entry No.");
        UpdatePOSCardEntryAuthorization(pToCardEntry, pFromCardRequestEntry);
        UpdatePOSCardEntryByBIN(pToCardEntry, pFromCardRequestEntry.BIN);
        pToCardEntry.Modify(TRUE);
    end;

    procedure TransferInfoToPOSTransLine(pPOSTransaction: Record "LSC POS Transaction")
    var
        terminal: Code[20];
        store: Code[20];
        auth: Text;
        errtxt: Label 'information of card transaction not found!';
        ValidateW: Text;
        POSCardEntryFilt: Record "FSN POS Card Request Entry";
    begin
        RetailSetup.Get();
        if not IsManualSetup() then begin
            RetailSetup."Distribution Location" := pPOSTransaction."POS Terminal No.";
            RetailSetup."Local Store No." := pPOSTransaction."Store No.";
        end;
        POSTransLine.Reset();
        POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine.SetRange("Receipt No.", pPOSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Payment);
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then
            repeat
                if TenderTypeSetup.Get(POSTransLine.Number) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then begin
                    if not GetLastRecord(POSCardEntry, POSTransLine."Store No.", POSTransLine."POS Terminal No.", POSTransLine."Receipt No.", POSTransLine."Line No.") then
                        Error(errtxt);

                    POSTransLine."FSN PC Entry No." := POSCardEntry."Entry No.";
                    if POSCardEntry."Auth.code" = '' then
                        POSCardEntry."Auth.code" := 'X';
                    if POSCardEntry."EFT Trans. No." = '' then
                        POSCardEntry."EFT Trans. No." := 'X';
                    if POSCardEntry."Expiry Date" = '' then
                        POSCardEntry."Expiry Date" := 'X';
                    if POSCardEntry."FSN CVV" = '' then
                        POSCardEntry."FSN CVV" := 'X';
                    if POSCardEntry."EFT Additional ID" = '' then
                        POSCardEntry."Card Number" := 'X'
                    else begin
                        if POSCardEntry."Card Number" = ' ' then
                            POSCardEntry."Card Number" := POScardExtConextion.DecryptCardNumber(POSCardEntry."EFT Additional ID", POSCardEntry."Receipt No.");
                    end;
                    POSTransLine."FSN PC Encrypt Security" := POSCardEntry."EFT Additional ID";
                    if POSCardEntry."EFT Device Name" = 'WOMPI' then
                        ValidateW := POSCardEntry."EFT Device Name"
                    ELSE
                        ValidateW := POSCardEntry."Expiry Date";
                    POSTransLine."FSN PC Information" :=
                            BOUTIL.CombineValue(5, POSCardEntry."Auth.code", POSCardEntry."EFT Trans. No.", ValidateW, POSCardEntry."FSN CVV", POSCardEntry."Card Number");
                    if POSCardEntry."Authorisation Ok" then begin
                        POSTransLine."FSN PC Authorization Ok" := POSTransLine."FSN PC Authorization Ok"::Ok;
                        POSTransLine."FSN PC Request Entry" := POSCardEntry."FSN Operation Name";
                        POSTransLine."FSN PC Encrypt Security" := '';
                    end else begin

                        POSTransLine."FSN PC Original Amount" := POSCardEntry."FSN Print Amount";
                        if (POSCardEntry."EFT Device Name" = 'WOMPI') and
                            (POSCardEntry."FSN Bank Name" = 'WOMPI') and
                            (POSCardEntry."FSN BIN No." = '0000') then begin

                            POSTransLine."FSN PC Authorization Ok" := POSTransLine."FSN PC Authorization Ok"::ManualOk;
                            POSTransLine."FSN PC Encrypt Security" := '';
                        end else begin
                            POSTransLine."FSN PC Authorization Ok" := POSTransLine."FSN PC Authorization Ok"::WithoutAuthorization;
                        end;
                    end;
                    POSTransLine."FSN PC Aditional Description" := POSCardEntry."EFT Terminal ID";
                    POSTransLine.Modify();
                end;
            until POSTransLine.Next() = 0;
    end;

    procedure TransformInfoToPosCardEntry(Receipt: Code[20])
    var
        batch: Code[20];
        val: Text[50];
    begin
        if not POSTransaction.Get(Receipt) then
            exit;
        RetailSetup.Get();
        if IsManualSetup() then
            exit;

        POSTransLine.Reset();
        POSTransLine.SetCurrentKey("Receipt No.", "Entry Type", "Entry Status");
        POSTransLine.SetRange("Receipt No.", POSTransaction."Receipt No.");
        POSTransLine.SetRange("Entry Type", POSTransLine."Entry Type"::Payment);
        POSTransLine.SetRange("Entry Status", POSTransLine."Entry Status"::" ");
        if POSTransLine.Find('-') then
            repeat
                batch := 'STORE';
                if POSTransLine."FSN PC Authorization Ok" <> 0 then begin
                    batch := 'PREPAYMENT';
                    if TenderTypeSetup.Get(POSTransLine.Number) and (TenderTypeSetup."FSN Function in CC" = TenderTypeSetup."FSN Function in CC"::Card) then begin
                        if not GetLastRecord(POSCardEntry, POSTransLine."Store No.", POSTransLine."POS Terminal No.", POSTransLine."Receipt No.", POSTransLine."Line No.") then begin
                            InitPOSCardEntryByPOSTransLine(POSTransLine, POSTransaction, batch);
                            GetLastRecord(POSCardEntry, POSTransLine."Store No.", POSTransLine."POS Terminal No.", POSTransLine."Receipt No.", POSTransLine."Line No.")
                        end;
                        val := BOUTIL.SeparateCombinedValue(1, POSTransLine."FSN PC Information");
                        if val <> 'X' then begin
                            POSCardEntry."Auth.code" := val;
                            POSCardEntry."MSR input" := true;
                        end;
                        val := BOUTIL.SeparateCombinedValue(2, POSTransLine."FSN PC Information");
                        if val <> 'X' then
                            POSCardEntry."EFT Trans. No." := val;
                        val := BOUTIL.SeparateCombinedValue(3, POSTransLine."FSN PC Information");
                        if val <> 'X' then begin
                            IF val = 'WOMPI' then
                                POSCardEntry."EFT Device Name" := val
                            else
                                POSCardEntry."Expiry Date" := val;
                        end;
                        val := BOUTIL.SeparateCombinedValue(4, POSTransLine."FSN PC Information");
                        if val <> 'X' then
                            POSCardEntry."FSN CVV" := val;
                        val := BOUTIL.SeparateCombinedValue(5, POSTransLine."FSN PC Information");
                        if val <> 'X' then
                            POSCardEntry."Card Number" := val;
                        IF STRLEN(POSCardEntry."Card Number") >= 6 THEN BEGIN
                            POSCardEntry."FSN BIN No." := COPYSTR(POSCardEntry."Card Number", 1, 6);
                            POSCardEntry."FSN Last Digits" := COPYSTR(POSCardEntry."Card Number", STRLEN(POSCardEntry."Card Number") - 3);
                            IF BINList.GET(POSCardEntry."FSN BIN No.") THEN
                                POSCardEntry."FSN Bank Name" := BINList."Bank Name";
                        end;
                        IF POSCardEntry."EFT Device Name" = 'WOMPI' then begin
                            POSCardEntry."FSN Bank Name" := 'WOMPI';
                            POSCardEntry."FSN BIN No." := '0000';
                            POSCardEntry."FSN Last Digits" := '0000';
                            POSCardEntry."Expiry Date" := '0000';
                        end;
                        POSCardEntry."Authorisation Ok" := POSTransLine."FSN PC Authorization Ok" = POSTransLine."FSN PC Authorization Ok"::Ok;
                        POSCardEntry."Res.code" := '00';
                        POSCardEntry."EFT Additional ID" := POSTransLine."FSN PC Encrypt Security";
                        POSCardEntry."Transaction Type" := POSCardEntry."Transaction Type"::Offline;
                        POSCardEntry.Date := Today;
                        POSCardEntry.Time := Time;
                        POSCardEntry."FSN Print Amount" := POSCardEntry.Amount;
                        POSCardEntry."EFT Terminal ID" := POSTransLine."FSN PC Aditional Description";
                        POSCardEntry.Modify(true);
                        POSTransLine."FSN PC Authorization Ok" := 0;
                        POSTransLine.Modify();
                        POSSession.SetValue('FSNPRINTVOUCHER', '1');
                    end;
                end;
            until POSTransLine.Next() = 0;
    end;
    //BOTH
    local procedure ValidateMultiEmisor()
    var
        FSNParameterMultiemisor: Record "FSN Parameter";
    begin
        POSMenuLineTmp.INIT();//Init global procesor

        IF (gCommand <> 'MANCOMPRANOR') OR
        (BINList."Emisor Setup Code" = 'KINPOSBAC')
        THEN
            IF BINList.GET(POSCardRequestEntry.BIN) AND (BINList."Emisor Setup Code" <> '') THEN
                IF FSNParameterMultiemisor.GET(BINList."Emisor Setup Code", RetailSetup."Local Store No.") AND (FSNParameterMultiemisor."String Parameters 1 Json" <> '')
                  AND (FSNParameterMultiemisor."Value Text 1" <> '') AND (FSNParameterMultiemisor."Value Text 2" <> '') AND (FSNParameterMultiemisor.SetFilterData2 <> '')
                  THEN BEGIN
                    POSCardRequestEntry."Retailer ID" := FSNParameterMultiemisor."Value Text 1";
                    POSCardRequestEntry."Terminal ID" := FSNParameterMultiemisor."Value Text 2";
                    IF FSNParameterMultiemisor.SetFilterData1 <> '' THEN
                        POSCardRequestEntry."Entity Name" := FSNParameterMultiemisor.SetFilterData1;

                    POSMenuLineTmp."Sales Type Access" := BINList."Emisor Setup Code";
                    POSMenuLineTmp."Period Access" := COPYSTR(FSNParameterMultiemisor.SetFilterData2, 1, 10);
                    GlobalsFSNParameters."String Parameters 1 Json" := FSNParameterMultiemisor."String Parameters 1 Json";
                    GlobalsFSNParameters.Grupo := FSNParameterMultiemisor.Grupo;
                    IF BINList."Emisor Setup Code" = 'KINPOSBAC' THEN
                        POSCardRequestEntry."Entity Name" := 'CREDOMATIC';
                END;
    end;

    procedure ValidateTerms(pKinposID: code[10]; pPOSTransLine: Record "LSC POS Trans. Line"; pErrTxt: Text): Boolean
    var
        lText006: Label 'Amount must be higher to $1 in payment points';
        lText007: Label 'Amount cant be lower to $100 in terms';
    begin
        IF NOT GlobalsFSNParameters.GET('KINPOS', pPOSTransLine."POS Terminal No.") THEN BEGIN
            pErrTxt := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;
        IF NOT GlobalsFSNParameters.Activo THEN BEGIN
            pErrTxt := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;
        IF (pKinposID = '3') AND (pPOSTransLine.Amount < GlobalsFSNParameters."Limit Points") THEN BEGIN//Static Amt millas
            pErrTxt := lText006;
            exit(false);
        END;
        IF (pKinposID = '6') AND (pPOSTransLine.Amount < GlobalsFSNParameters."Limit Term 1") THEN BEGIN//Static Amt terms
            pErrTxt := lText007;
            exit(false);
        END;

        exit(true);
    end;
    //PINPAD
    procedure KinPosSendRequest(var ErrorText: Text; pPOSTransLine: Record "LSC POS Trans. Line"; cardEntryExists: Boolean): Boolean
    var
        ResponseCode: Text;
        AmountText: Text[12];
        EntryLocalNo: Integer;
        ErrorExec: Boolean;
        "Filter": Code[20];
        LookupSetup: Record "LSC POS Lookup";
        ParametersVar: Record "FSN Parameter";
        MgrKey: Boolean;
        CustomerNo: Code[20];
        pRecRef: RecordRef;
        LookRespCode: Code[30];
        PosTransLine: Record "LSC POS Trans. Line" temporary;
        PosTransLine2: Record "LSC POS Trans. Line" temporary;
        LookupRecRef: RecordRef;
        TransCardType: Integer;
    begin
        gDateContext := TODAY;
        RetailSetup.GET;
        AmountText := DataCnn.GetTextInput(pPOSTransLine.Amount);
        POSTransaction.GET(pPOSTransLine."Receipt No.");

        POSCardRequestEntry.RESET;
        POSCardRequestEntry.SETCURRENTKEY("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Receipt No.", pPOSTransLine."Receipt No.");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Line No.", pPOSTransLine."Line No.");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Enter Input", AmountText);
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Response Web Ok", TRUE);
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Distribution Location", RetailSetup."Distribution Location");
        POSCardRequestEntry.SETRANGE(POSCardRequestEntry."Date Key", gDateContext);
        IF POSCardRequestEntry.FINDFIRST THEN BEGIN
            KinPosInsertFromRequest(POSCardRequestEntry, pPOSTransLine);
            EXIT(TRUE);
        END;

        LookRespCode := POSSession.GetValue('#FORM_KINPOS_ID');
        IF LookRespCode = '' THEN BEGIN
            ParametersVar.RESET;
            ParametersVar.SETCURRENTKEY(Grupo, Codigo);
            ParametersVar.SETRANGE(ParametersVar.Grupo, GlobalsFSNParameters."Lookup ID 1");
            IF ParametersVar.FINDFIRST THEN
                LookRespCode := ParametersVar.Codigo;
        END;

        IF NOT EVALUATE(TransCardType, LookRespCode) THEN BEGIN
            ErrorText := Text014;
            EXIT(FALSE);
        END;

        IF NOT KinPosPostCardPinPad(pPOSTransLine, AmountText, ErrorText, EntryLocalNo, TransCardType) THEN
            EXIT(FALSE);

        KinPosInsertFromRequest(POSCardRequestEntry, pPOSTransLine);
        EXIT(TRUE);
    end;

    //PINPAD
    procedure KinPosPostCardPinPad(pPOSTransLine: Record "LSC POS Trans. Line"; pAmount: Text[12]; var pErrorText: Text; var pEntryNextNo: Integer; TypeTransaction: Integer): Boolean
    var
        lText001: Label '% config. not exists or is not complete';
        lText002: Label 'Response of reader is invalid';
        lText003: Label 'Try fail!';
        lText004: Label '%1';
        lText005: Label 'Insert or Swip card..';
        lText006: Label 'Charging %1...';
        lText007: Label 'Validate...';
        lText008: Label 'normal';
        lText009: Label 'with Points';
        lText010: Label 'to terms';
        lText011: Label 'Terms must be between 1 and 99';
        lText012: Label 'Query points..';
        lText018: Label 'cant be read card from pinpad. Error %1';
        lText013: Label 'Card Repeat.\Continue card \%1?';
        lText014: Label 'Cancelled';
        lText015: Label 'Alert';
        lText017: Label 'Coupon %1, is not permited for BIN %2 ';
        lText016: Label 'BIN Block for Pinpad: %1';
        WindowsText: Text[100];
        jSonParameters: Text;
        jSonResponse: Text;
        Windows: Dialog;
        PlzoInt: Integer;
        PlzoText: Text[12];
        Altert: Boolean;
        pCouponCode: Code[20];
        pCouponDescription: Text[50];
        ParametersVar_l: Record "FSN Parameter";
        tmpPOSTransRequest: Record "FSN POS Card Request Entry" temporary;
        POSRequestLocal: Record "FSN POS Card Request Entry";
        TenderTypeSetup_l: Record "LSC Tender Type Setup";
        TransactionHdr: Record "LSC Transaction Header";
        ParametersMulti_l: Record "FSN Parameter";
        POSDataTemporary_l: Record "FSN POS Data Temporary";
        POSprintUtil: Codeunit "LSC POS Print Utility";
    begin
        //TypeTransaction = 1 Normal, 3 points buy, 6 terms
        POSCardRequestEntry.RESET;
        CLEAR(POSCardRequestEntry);
        gDateContext := TODAY;
        pEntryNextNo := 0;
        gDataEMV := '';
        gDataBAN := '';
        gDataPin := '';
        gDataSeqNo := '';
        RetailSetup.GET();

        PlzoText := '';
        PlzoInt := 0;
        IF ParametersVar_l.GET('KINPOSF', FORMAT(TypeTransaction)) THEN
            IF ParametersVar_l.Descripcion = 'PLZO' THEN BEGIN
                PlzoText := POSSession.GetValue('#FORM_KINPOS_PLZO');
                IF NOT EVALUATE(PlzoInt, PlzoText) THEN BEGIN
                    pErrorText := lText011;
                    EXIT(FALSE);
                END ELSE
                    IF NOT (PlzoInt > 0) AND (PlzoInt < 100) THEN BEGIN
                        pErrorText := lText011;
                        EXIT(FALSE);
                    END;
            END;

        IF (GlobalsFSNParameters."String Parameters 1 Json" = '') OR
          (GlobalsFSNParameters."Port Text" = '') OR
          (GlobalsFSNParameters."Value Text 1" = '') OR
          (GlobalsFSNParameters."Value Text 2" = '') THEN BEGIN
            pErrorText := STRSUBSTNO(lText001);
            EXIT(FALSE);
        END;

        WindowsText := lText005;
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        POSMenuLineTmp.RESET;
        POSMenuLineTmp.DELETEALL;
        POSMenuLineTmp.Init();
        Clear(DataCnn);
        POSMenuLineTmp.Command := 'KINPOS_READ';
        POSMenuLineTmp.Parameter := pAmount;
        DataCnn.InitGlobalsFSNParameters(GlobalsFSNParameters);
        DataCnn.InitRequestGlobals('', '', DataCnn.GetPinpadWebParameters(GlobalsFSNParameters), '', '', '', '', '', '');
        Commit();
        if not DataCnn.Run(POSMenuLineTmp) then begin
            pErrorText := STRSUBSTNO(lText018, GetLastErrorText());
            EXIT(FALSE);
        end;
        jSonResponse := DataCnn.GetResponseGlobals();

        DataCnn.GetPOSCardReqEntryTmpFromResponsePinpadWeb(jSonResponse, tmpPOSTransRequest, gDataBAN, gDataEMV, pErrorText, gDataPin, gDataPosEntryMode, gDataSeqNo);

        Windows.CLOSE;
        WindowsText := lText007;
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        IF NOT tmpPOSTransRequest.FIND('-')
          OR NOT (tmpPOSTransRequest."Entry Mode" IN ['S', 'V', 'I', 'C'])
          OR NOT tmpPOSTransRequest."Response Web Ok"
          OR (tmpPOSTransRequest.BIN = '000000') THEN BEGIN
            //SLEEP(2000);//WVILLALTA 8.20
            KinposSaveErrorReadCard(tmpPOSTransRequest, pPOSTransLine, TypeTransaction);
            Windows.CLOSE();
            //PinPadRead.CloseTransaction('', 'RR');
            //SLEEP(1500);//WVILLALTA05JUN2020-+
            pErrorText := lText002;
            EXIT(FALSE);
        END;

        //WILLALTA 06.21-
        CLEAR(Altert);
        POSDataTemporary_l.RESET;
        POSDataTemporary_l.SETCURRENTKEY("Type Phrase", "Key No.", "Key Date", "Key Location");
        POSDataTemporary_l.SETRANGE("Type Phrase", POSDataTemporary_l."Type Phrase"::"Card Request Entry");
        POSDataTemporary_l.SETRANGE("Key Date", TODAY);
        POSDataTemporary_l.SETRANGE("Key Location", RetailSetup."Distribution Location");
        IF POSDataTemporary_l.FINDLAST THEN
            IF POScardExtConextion.DecryptCardNumber(POSDataTemporary_l.Value, POSDataTemporary_l."Receipt No.") = tmpPOSTransRequest."Card Filter" THEN BEGIN
                //cambiar la validacion o duplicar
                Commit();
                IF NOT POSGUI.PosConfirm(STRSUBSTNO(lText013, COPYSTR(tmpPOSTransRequest.BIN, 1, 4) + '********' + tmpPOSTransRequest."Cast Last Numbers"), FALSE) THEN BEGIN
                    pErrorText := lText014;
                    //PinPadRead.CloseTransaction('', 'RR');
                    EXIT(FALSE);
                END ELSE
                    Altert := TRUE;
            END;

        CLEAR(POSCardRequestEntry);
        //WILLALTA 06.21+
        GetBinList(tmpPOSTransRequest.BIN);
        IF ((TypeTransaction IN [1, 3, 6]) AND TenderTypeSetup_l.GET(pPOSTransLine.Number) AND TenderTypeSetup_l."FSN Used By Specific BIN") OR
          ((TypeTransaction IN [1, 3, 6]) AND (BINList."Tender Type Default" <> '') AND TenderTypeSetup_l.GET(pPOSTransLine.Number)) THEN
            IF BINList."Tender Type Default" <> TenderTypeSetup_l.Code THEN BEGIN
                //SLEEP(2000);//WVILLALTA 8.20
                //PinPadRead.CloseTransaction('', 'RR');
                pErrorText := STRSUBSTNO(Text017, TenderTypeSetup_l.Description, BINList."BIN/IIN");
                EXIT(FALSE);
            END;

        POSCardRequestEntry.INIT();
        POSCardRequestEntry."Date Key" := gDateContext;
        POSCardRequestEntry."Distribution Location" := RetailSetup."Distribution Location";
        POSCardRequestEntry.VALIDATE(POSCardRequestEntry."Entry No.");
        pEntryNextNo := POSCardRequestEntry."Entry No.";
        POSCardRequestEntry."Bank Name" := COPYSTR(BINList."Bank Name", 1, MAXSTRLEN(POSCardRequestEntry."Bank Name"));
        POSCardRequestEntry."Authorization Code" := '';//Clear
        POSCardRequestEntry."Receipt ID" := GenerateReceiptID(POSCardRequestEntry."Entry No.");
        POSCardRequestEntry."Send Audit No" := GenerateReceiptID(POSCardRequestEntry."Entry No.");
        POSCardRequestEntry."Entity Name" := 'SERFINSA';
        POSCardRequestEntry."Type Request" := POSCardRequestEntry."Type Request"::POS;
        POSCardRequestEntry."Receipt No." := pPOSTransLine."Receipt No.";
        POSCardRequestEntry."Store No." := pPOSTransLine."Store No.";
        POSCardRequestEntry."Line No." := pPOSTransLine."Line No.";
        POSCardRequestEntry."Enter Input" := pAmount;
        POSCardRequestEntry."Tender Type" := pPOSTransLine.Number;
        POSCardRequestEntry.User := USERID;
        POSCardRequestEntry."Customer No." := POSTransaction."Customer No.";
        POSCardRequestEntry.Date := CURRENTDATETIME;
        // POSCardRequestEntry."Entry Mode" := ConvertModeNumber(tmpPOSTransRequest."Entry Mode");
        POSCardRequestEntry."Entry Mode" := gDataPosEntryMode;
        POSCardRequestEntry."Card Last Date" := tmpPOSTransRequest."Card Last Date";
        POSCardRequestEntry."Cast Last Numbers" := tmpPOSTransRequest."Cast Last Numbers";
        POSCardRequestEntry.BIN := tmpPOSTransRequest.BIN;
        POSCardRequestEntry."Retailer ID" := GlobalsFSNParameters."Value Text 1";
        POSCardRequestEntry."Terminal ID" := GlobalsFSNParameters."Value Text 2";
        IF gDataPin <> '0000000000000000' THEN
            POSCardRequestEntry.Command := 'EMVCOMPRAPIN'
        ELSE
            POSCardRequestEntry.Command := ConvertCommandGeneric(TypeTransaction, tmpPOSTransRequest."Entry Mode");//1 BUY/VOID, 2 QRYPOINT

        POSCardRequestEntry.Plazo := '';
        IF (PlzoInt < 10) AND (PlzoInt > 0) THEN
            POSCardRequestEntry.Plazo := '0' + PlzoText
        ELSE
            IF PlzoInt >= 10 THEN
                POSCardRequestEntry.Plazo := PlzoText;
        POSCardRequestEntry."Card Filter" := tmpPOSTransRequest."Card Filter";//For POS Data Temporary
        //POSCardRequestEntry.INSERT(TRUE);
        IF Altert THEN
            POSCardRequestEntry.Folio := lText015;

        POSMenuLineTmp.RESET;
        POSMenuLineTmp.DELETEALL;
        CLEAR(POSMenuLineTmp);
        POSMenuLineTmp.INIT();
        POSMenuLineTmp.Command := 'KINPOS_SALE';
        POSMenuLineTmp.Parameter := POSCardRequestEntry.Command;
        POSMenuLineTmp."Current-GUEST" := TypeTransaction;
        POSMenuLineTmp."Post Parameter" := tmpPOSTransRequest."Retailer ID";//Temporary card
        POSMenuLineTmp."Current-INPUT" := pAmount;
        POSMenuLineTmp."POS Key Code" := pEntryNextNo;
        //POSMenuLineTmp.Description := PinPadRead.IP();
        POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
        POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);

        ChangeMultiemisorParameters(BINList, POSCardRequestEntry, TypeTransaction, pErrorText);
        POSCardRequestEntry.INSERT(TRUE);

        POSMenuLineTmp.INSERT;

        Windows.CLOSE;
        IF TypeTransaction = 2 THEN
            WindowsText := POSCardRequestEntry."Entity Name" + ' ' + lText012
        ELSE
            WindowsText := POSCardRequestEntry."Entity Name" + ' ' + POSSession.GetValue('#FORM_KINPOS_NAME');

        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        COMMIT;
        CLEARLASTERROR();
        DataCnn.InitRequestGlobals(gDataEMV, gDataBAN, '', '', '', '', '', gDataPin, gDataSeqNo);
        DataCnn.InitGlobalsFSNParameters(GlobalsFSNParameters);
        IF DataCnn.RUN(POSMenuLineTmp) THEN;
        COMMIT;

        Windows.CLOSE;
        IF NOT POSRequestLocal.GET(POSCardRequestEntry."Entry No.", POSCardRequestEntry."Date Key", POSCardRequestEntry."Distribution Location") THEN BEGIN
            pErrorText := lText003;
            EXIT(FALSE);
        END;

        IF (TypeTransaction = 2) AND (POSRequestLocal."Authorization Code" = 'OK') THEN BEGIN
            // PinPadRead.CloseTransaction('', '00');
            EXIT(TRUE);
        END;

        CASE POSRequestLocal."Authorization Code" OF
            '00':
                BEGIN
                    //PinPadRead.CloseTransaction(POSRequestLocal."Trans Authorization", POSRequestLocal."Authorization Code");
                    CLEAR(TransactionHdr);//WVILLALTA05JUN2020-
                    TransactionHdr."Store No." := POSRequestLocal."Store No.";
                    TransactionHdr."Receipt No." := POSRequestLocal."Receipt No.";
                    TransactionHdr."Sale Is Return Sale" := FALSE;

                    PrintCardVoucherRequest(TransactionHdr, POSRequestLocal."Receipt No.", false, true, POSRequestLocal."Line No.");
                    pErrorText := DataCnn.SRFGetErrorCodeText(POSRequestLocal."Authorization Code");
                    //PrintCardVoucherRequest(POSRequestLocal, 2, 0, COPYSTR(pErrorText, 1, 100));
                    COMMIT;//WVILLALTA05JUN2020+
                    EXIT(TRUE);
                END;
            '':
                BEGIN
                    pErrorText := Text013;
                    SLEEP(1500);//WVILLALTA 8.20
                    //PinPadRead.CloseTransaction('', 'RR');
                    PrintCardVoucherRequest(POSRequestLocal, 2, 0, COPYSTR(pErrorText, 1, 100));//Print
                    EXIT(FALSE);
                END;
            ELSE BEGIN
                //PinPadRead.CloseTransaction('', POSRequestLocal."Authorization Code");
            END;
        END;

        SLEEP(1500); //WVILLALTA 8.20
        pErrorText := DataCnn.SRFGetErrorCodeText(POSRequestLocal."Authorization Code");
        PrintCardVoucherRequest(POSRequestLocal, 2, 0, COPYSTR(pErrorText, 1, 100));//Print

        EXIT(FALSE);
    end;

    //PINPAD
    procedure ChangeMultiemisorParameters(pBINTable: Record "FSN BIN Bank"; var pRec: Record "FSN POS Card Request Entry"; pTypeTransaction: Integer; var pMsgError: Text): Boolean
    var
        ParametersVar_l, agricolaParameter : Record "FSN Parameter";
        POSTRANS: Record "LSC POS Transaction";
        session: Codeunit "LSC POS Session";
        POSTransC: Codeunit "LSC POS Transaction";
        lTxt1: Label '%1 %2 is not configured';
    begin
        //TypeTransaction = 1 Normal, 3 points buy, 6 terms

        POSTRANS.Get(POSTransC.GetReceiptNo());
        //? Validar el Parametro original
        if ParametersVar_l.Get('KINPOS', POSTRANS."POS Terminal No.") and (ParametersVar_l."String Parameters 2 Json" = 'BLOCK') and (pTypeTransaction = 1) THEN
            EXIT;

        //? Evalua si se necesita cmabiar los valores de texto para el uso de n1co en caso de usar puntos
        if (pTypeTransaction = 1) and agricolaParameter.Get('KINPOSN1CO', session.TerminalNo()) and agricolaParameter.Activo then begin
            parametersVar_l."Value Text 1" := agricolaParameter."Value Text 1";
            parametersVar_l."Value Text 2" := agricolaParameter."Value Text 2";
        end;

        RetailSetup.GET;
        IF pBINTable."Emisor Setup Code" = '' THEN
            EXIT(TRUE);
        IF NOT ParametersVar_l.GET(pBINTable."Emisor Setup Code", POSTRANS."POS Terminal No.") THEN
            pMsgError := STRSUBSTNO(lTxt1, ParametersVar_l.TABLECAPTION, pBINTable."Emisor Setup Code");
        IF (pMsgError = '') AND ((ParametersVar_l."Value Text 1" = '') OR (ParametersVar_l."Value Text 2" = '')) THEN
            pMsgError := STRSUBSTNO(lTxt1, ParametersVar_l.TABLECAPTION, pRec.FIELDCAPTION("Terminal ID"));
        IF (pTypeTransaction = 6) AND (pMsgError = '') AND (ParametersVar_l.SetFilterData2 = '') THEN //Terms
            pMsgError := STRSUBSTNO(lTxt1, ParametersVar_l.TABLECAPTION, pRec.FIELDCAPTION(pRec.Plazo));
        IF (pMsgError = '') AND (ParametersVar_l."String Parameters 1 Json" = '') THEN
            pMsgError := STRSUBSTNO(lTxt1, ParametersVar_l.TABLECAPTION, ParametersVar_l.FIELDCAPTION("String Parameters 1 Json"));
        IF pMsgError <> '' THEN
            EXIT(FALSE);

        IF ParametersVar_l.SetFilterData1 <> '' THEN
            pRec."Entity Name" := ParametersVar_l.SetFilterData1;

        pRec."Retailer ID" := ParametersVar_l."Value Text 1";
        pRec."Terminal ID" := ParametersVar_l."Value Text 2";

        POSMenuLineTmp."Data ID" := BINList."Emisor Setup Code";
        POSMenuLineTmp."Period Access" := COPYSTR(ParametersVar_l.SetFilterData2, 1, 10);

        GlobalsFSNParameters.Grupo := ParametersVar_l.Grupo; //WVILLALTA 06.21 #2-

        GlobalsFSNParameters."String Parameters 1 Json" := ParametersVar_l."String Parameters 1 Json";//Change security
    end;

    //PINPAD
    procedure KinPosSendPointsRequest(pPosTransaction: Record "LSC POS Transaction"; var pPointsAmount: Decimal; var pPoints: Decimal; var pErrorText: Text): Boolean
    var
        lText001: Label '% config. not exists';
        lText002: Label 'Response of reader is invalid';
        lText003: Label 'Try fail!';
        lText004: Label '%1';
        lText005: Label 'Insert or Swip card..';
        lText006: Label 'charging..';
        lText007: Label 'Validate...';
        pPOSTransLine: Record "LSC POS Trans. Line";
        pAmount: Text[12];
        pEntryNextNo: Integer;
    begin
        RetailSetup.GET();
        IF NOT GlobalsFSNParameters.GET('KINPOS', pPosTransaction."POS Terminal No.") THEN BEGIN
            pErrorText := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;
        IF NOT GlobalsFSNParameters.Activo THEN BEGIN
            pErrorText := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;

        pPointsAmount := 0;
        pPoints := 0;
        pPOSTransLine.RESET;
        pPOSTransLine.INIT();
        pPOSTransLine."Receipt No." := pPosTransaction."Receipt No.";
        pPOSTransLine."Line No." := 1;
        pPOSTransLine."Store No." := pPosTransaction."Store No.";
        pPOSTransLine."POS Terminal No." := RetailSetup."Distribution Location";
        IF NOT KinPosPostCardPinPad(pPOSTransLine, '', pErrorText, pEntryNextNo, 2) THEN
            EXIT(FALSE);

        IF NOT (POSCardRequestEntry.GET(pEntryNextNo, TODAY, RetailSetup."Distribution Location")) OR
          (POSCardRequestEntry."Authorization Code" <> 'OK') THEN BEGIN
            IF pErrorText = '' THEN
                pErrorText := Text013;
            EXIT(FALSE);
        END;

        PrintCardVoucherRequest(POSCardRequestEntry, 2, 2, COPYSTR(pErrorText, 1, 100));//Print

        IF EVALUATE(pPoints, POSCardRequestEntry.Points) THEN;
        pPoints := pPoints / 100;

        IF EVALUATE(pPointsAmount, POSCardRequestEntry."Amount Input") THEN;
        pPointsAmount := pPointsAmount / 100;
        EXIT(TRUE);
    end;

    //PINPAD
    procedure KinPosSendVoidRequest(var ErrorText: Text; pPOSTransLine: Record "LSC POS Trans. Line"; pPosCardEntryOld: Record "LSC POS Card Entry"): Boolean
    var
        ResponseCode: Text;
        AmountText: Text[12];
        EntryLocalNo: Integer;
        ErrorExec: Boolean;
        Value_: Text;
        Day_: Integer;
        Month_: Integer;
        Year_: Integer;
        EntryOldNo_: Integer;
        DistLocation: Code[10];
        WindowsText: Text;
        Windows: Dialog;
        lText001: Label 'Request origin not exists';
        lText002: Label 'Validate...';
        lText003: Label 'Return procesing...';
        ParametersVar: Record "FSN Parameter";
        POSRequestOld: Record "FSN POS Card Request Entry";
        POSRequestLocal: Record "FSN POS Card Request Entry";
        RecValidateReturn: Record "FSN POS Card Request Entry";
        POSDataTemporary: Record "FSN POS Data Temporary";
        TransactionHdr: Record "LSC Transaction Header";
        POSPrintUtil: Codeunit "LSC POS Print Utility";
        POSCardEntryReturn: Record "LSC POS Card Entry";
        Header: Record "LSC POS Transaction";
        Err2: Text;
    begin
        IF NOT GlobalsFSNParameters.GET('KINPOS', pPOSTransLine."POS Terminal No.") THEN BEGIN
            ErrorText := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;
        IF NOT GlobalsFSNParameters.Activo THEN BEGIN
            ErrorText := STRSUBSTNO(Text011, pPOSTransLine."POS Terminal No.");
            EXIT(FALSE);
        END;

        IF GetLastRecord(POSCardEntry, pPOSTransLine."Store No.", pPOSTransLine."POS Terminal No.",
                                            pPOSTransLine."Receipt No.", pPOSTransLine."Line No.") then
            if POSCardEntry."Authorisation Ok" and (POSCardEntry.Amount = pPOSTransLine.Amount) then
                exit;

        AmountText := DataCnn.GetTextInput(pPOSTransLine.Amount);
        IF pPosCardEntryOld."FSN Operation Name" = '' THEN BEGIN
            ErrorText := lText001;
            EXIT(FALSE);
        END;
        Value_ := BOUTIL.SeparateCombinedValue(1, COPYSTR(pPosCardEntryOld."FSN Operation Name", 1, 100));
        EVALUATE(EntryOldNo_, Value_);
        Value_ := BOUTIL.SeparateCombinedValue(2, COPYSTR(pPosCardEntryOld."FSN Operation Name", 1, 100));
        EVALUATE(Day_, Value_);
        Value_ := BOUTIL.SeparateCombinedValue(3, COPYSTR(pPosCardEntryOld."FSN Operation Name", 1, 100));
        EVALUATE(Month_, Value_);
        Value_ := BOUTIL.SeparateCombinedValue(4, COPYSTR(pPosCardEntryOld."FSN Operation Name", 1, 100));
        EVALUATE(Year_, Value_);
        DistLocation := BOUTIL.SeparateCombinedValue(5, COPYSTR(pPosCardEntryOld."FSN Operation Name", 1, 100));

        IF NOT POSRequestOld.GET(EntryOldNo_, DMY2DATE(Day_, Month_, Year_), DistLocation) THEN BEGIN
            ErrorText := lText001;
            EXIT(FALSE);
        END;

        RecValidateReturn.RESET;
        RecValidateReturn.SETCURRENTKEY("Response Web Ok", "Void Number");
        RecValidateReturn.SETRANGE(RecValidateReturn."Response Web Ok", TRUE);
        RecValidateReturn.SETRANGE(RecValidateReturn."Void Number", POSRequestOld."Entry No.");
        RecValidateReturn.SETRANGE(RecValidateReturn."Void Date Key", POSRequestOld."Date Key");
        RecValidateReturn.SETRANGE(RecValidateReturn."Void Dist. Location", POSRequestOld."Distribution Location");
        IF RecValidateReturn.FINDFIRST THEN BEGIN
            Header.Get(pPOSTransLine."Receipt No.");
            InitPOSCardEntryByPOSTransLine(pPOSTransLine, Header, 'NORMAL');
            GetLastRecord(POSCardEntryReturn, pPOSTransLine."Store No.", pPOSTransLine."POS Terminal No.", pPOSTransLine."Receipt No.", pPOSTransLine."Line No.");
            UpdatePOSCardEntryAuthorization(POSCardEntryReturn, RecValidateReturn);

            POSCardEntryReturn."Transaction Type" := POSCardEntryReturn."Transaction Type"::"Void Sale";
            POSCardEntryReturn."EFT Transaction Type" := POSCardEntryReturn."EFT Transaction Type"::Refund;
            POSCardEntryReturn.Modify(true);
            //pPosCardEntry."Authorisation Ok" := TRUE;
            //pPosCardEntry."MSR input" := TRUE;
            //pPosCardEntry."Auth.code" := RecValidateReturn."Trans Authorization";
            //pPosCardEntry."Res.code" := RecValidateReturn."Authorization Code";
            //pPosCardEntry."Transaction Type" := pPosCardEntry."Transaction Type"::"Void Sale";
            EXIT(TRUE);
        END;
        gDataBAN := '0000000000000000=00000000000000000000';
        IF NOT POSDataTemporary.GET(POSDataTemporary."Type Phrase"::"Card Request Entry", POSRequestOld."Entry No.", POSRequestOld."Date Key", POSRequestOld."Distribution Location") THEN BEGIN
            ErrorText := lText001;
            EXIT(FALSE);
        END;
        gCard := POScardExtConextion.DecryptCardNumber(POSDataTemporary.Value, POSDataTemporary."Receipt No.");

        gDateContext := TODAY;
        POSTransaction.GET(pPOSTransLine."Receipt No.");
        POSCardRequestEntry.RESET;
        CLEAR(POSCardRequestEntry);
        POSCardRequestEntry.INIT();

        WindowsText := lText002;
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        GetBinList(pPosCardEntryOld."FSN BIN No.");
        ChangeMultiemisorParameters(BINList, POSCardRequestEntry, 5, Err2);

        POSCardRequestEntry."Date Key" := gDateContext;
        POSCardRequestEntry."Distribution Location" := POSRequestOld."Distribution Location";
        POSCardRequestEntry.VALIDATE(POSCardRequestEntry."Entry No.");
        EntryLocalNo := POSCardRequestEntry."Entry No.";
        POSCardRequestEntry."Receipt ID" := POSRequestOld."Receipt ID";
        IF POSRequestOld."Trans Audit No" <> '' THEN
            POSCardRequestEntry."Send Audit No" := POSRequestOld."Trans Audit No"
        ELSE
            POSCardRequestEntry."Send Audit No" := POSRequestOld."Send Audit No";
        POSCardRequestEntry."Cast Last Numbers" := POSRequestOld."Cast Last Numbers";
        POSCardRequestEntry.BIN := POSRequestOld.BIN;
        POSCardRequestEntry."Card Last Date" := POSRequestOld."Card Last Date";
        POSCardRequestEntry.CVV := POSRequestOld.CVV;
        POSCardRequestEntry."Bank Name" := POSRequestOld."Bank Name";
        POSCardRequestEntry."Entry Mode" := '012';//POSRequestOld."Entry Mode"; Static in return
        POSCardRequestEntry."Entity Name" := POSRequestOld."Entity Name";
        POSCardRequestEntry."Type Request" := POSRequestOld."Type Request";
        POSCardRequestEntry."Receipt No." := pPOSTransLine."Receipt No.";
        POSCardRequestEntry."Line No." := pPOSTransLine."Line No.";
        POSCardRequestEntry."Store No." := pPOSTransLine."Store No.";
        POSCardRequestEntry."Tender Type" := pPOSTransLine.Number;
        POSCardRequestEntry."Enter Input" := POSRequestOld."Amount Input";
        POSCardRequestEntry.User := USERID;
        POSCardRequestEntry."Customer No." := POSRequestOld."Customer No.";
        POSCardRequestEntry.Date := CURRENTDATETIME;
        POSCardRequestEntry.Command := POSRequestOld.Command + 'A';//Void
        POSCardRequestEntry."Retailer ID" := POSRequestOld."Retailer ID";
        POSCardRequestEntry."Terminal ID" := POSRequestOld."Terminal ID";
        POSCardRequestEntry."Void Number" := POSRequestOld."Entry No.";
        POSCardRequestEntry."Void Date Key" := POSRequestOld."Date Key";
        POSCardRequestEntry."Void Dist. Location" := POSRequestOld."Distribution Location";
        POSCardRequestEntry."Trans Authorization" := POSRequestOld."Trans Authorization";//Override
        POSCardRequestEntry."Card Filter" := gCard;
        POSCardRequestEntry.INSERT(TRUE);

        POSMenuLineTmp.RESET;
        POSMenuLineTmp.DELETEALL;
        CLEAR(POSMenuLineTmp);
        POSMenuLineTmp.INIT();
        POSMenuLineTmp.Command := 'KINPOS_SALE';
        POSMenuLineTmp.Parameter := POSCardRequestEntry.Command;
        POSMenuLineTmp."Current-GUEST" := 1;
        POSMenuLineTmp."Current-INPUT" := POSCardRequestEntry."Enter Input";
        POSMenuLineTmp."Post Parameter" := gCard;//Card set
        POSMenuLineTmp."POS Key Code" := EntryLocalNo;
        //POSMenuLineTmp.Description := PinPadRead.IP();
        POSMenuLineTmp."Current-POSID" := POSCardRequestEntry."Distribution Location";
        POSMenuLineTmp.XPos := DATE2DMY(POSCardRequestEntry."Date Key", 1);
        POSMenuLineTmp.YPos := DATE2DMY(POSCardRequestEntry."Date Key", 2);
        POSMenuLineTmp.Width := DATE2DMY(POSCardRequestEntry."Date Key", 3);
        POSMenuLineTmp.INSERT;

        WindowsText := lText003;
        Windows.OPEN(WindowsText);
        Windows.UPDATE;

        CLEARLASTERROR();
        //DataCnn.SRFINIT();
        // DataCnn.SRFSetEMV(gDataEMV, gDataBAN);
        DataCnn.InitRequestGlobals(gDataEMV, gDataBAN, '', '', '', '', '', gDataPin, gDataSeqNo);
        DataCnn.InitGlobalsFSNParameters(GlobalsFSNParameters);
        COMMIT;
        IF DataCnn.RUN(POSMenuLineTmp) THEN;

        Windows.CLOSE;
        IF NOT POSRequestLocal.GET(POSCardRequestEntry."Entry No.", POSCardRequestEntry."Date Key", POSCardRequestEntry."Distribution Location") THEN BEGIN
            ErrorText := lText003;
            EXIT(FALSE);
        END;
        CASE POSRequestLocal."Authorization Code" OF
            '00':
                BEGIN
                    Header.Get(pPOSTransLine."Receipt No.");
                    InitPOSCardEntryByPOSTransLine(pPOSTransLine, Header, 'NORMAL');
                    GetLastRecord(POSCardEntryReturn, pPOSTransLine."Store No.", pPOSTransLine."POS Terminal No.", pPOSTransLine."Receipt No.", pPOSTransLine."Line No.");
                    UpdatePOSCardEntryAuthorization(POSCardEntryReturn, POSRequestLocal);

                    POSCardEntryReturn."Transaction Type" := POSCardEntryReturn."Transaction Type"::"Void Sale";
                    POSCardEntryReturn."EFT Transaction Type" := POSCardEntryReturn."EFT Transaction Type"::Refund;
                    POSCardEntryReturn.Modify(true);
                    /*
                    pPosCardEntry."Authorisation Ok" := TRUE;
                    pPosCardEntry."MSR input" := TRUE;
                    pPosCardEntry."Auth.code" := POSRequestLocal."Trans Authorization";
                    pPosCardEntry."Res.code" := POSRequestLocal."Authorization Code";
                    pPosCardEntry."Transaction Type" := pPosCardEntry."Transaction Type"::"Void Sale";
                    */
                    CLEAR(TransactionHdr);
                    TransactionHdr."Store No." := POSRequestLocal."Store No.";
                    TransactionHdr."Receipt No." := POSRequestLocal."Receipt No.";
                    TransactionHdr."Sale Is Return Sale" := TRUE;
                    PrintCardVoucherRequest(TransactionHdr, POSRequestLocal."Receipt No.", FALSE, TRUE, POSRequestLocal."Line No.");
                    COMMIT;//WVILLALTA05JUN2020+
                    EXIT(TRUE);
                END;
            '':
                BEGIN
                    ErrorText := Text013;
                    PrintCardVoucherRequest(POSRequestLocal, 2, 0, COPYSTR(ErrorText, 1, 100));//Print
                    EXIT(FALSE);
                END;
        END;

        ErrorText := DataCnn.SRFGetErrorCodeText(POSRequestLocal."Authorization Code");
        PrintCardVoucherRequest(POSRequestLocal, 2, 0, COPYSTR(ErrorText, 1, 100));//Print

        EXIT(FALSE);
    end;


    //PINPAD
    procedure KinPosInsertFromRequest(pPOSCardRequest: Record "FSN POS Card Request Entry"; pNewLine: Record "LSC POS Trans. Line")
    var
        lPOSCardEntry: Record "LSC POS Card Entry";
        POSMenuLineTmp2: Record "LSC POS Menu Line" temporary;
        pKey: Text;
    begin
        IF pPOSCardRequest.GET(pPOSCardRequest."Entry No.", pPOSCardRequest."Date Key", pPOSCardRequest."Distribution Location") THEN;
        lPOSCardEntry.RESET;
        lPOSCardEntry.Init();
        lPOSCardEntry."Store No." := pNewLine."Store No.";
        lPOSCardEntry."POS Terminal No." := pNewLine."POS Terminal No.";
        lPOSCardEntry."Line No." := pNewLine."Line No.";
        lPOSCardEntry."Transaction No." := 0;
        case pPOSCardRequest.Command of
            'BANCOMPRADEV',
            'BANCOMPRAMILA',
            'BANCOMPRANORA',
            'BANCOMPRAPLAA',
            'EMVCOMPRANORA',
            'EMVCOMPRAMILA',
            'EMVCOMPRAPLAA',
            'MANCOMPRAMILA',
            'MANCOMPRANORA',
            'MANCOMPRAPLAA':
                begin
                    lPOSCardEntry."Transaction Type" := lPOSCardEntry."Transaction Type"::"Void Sale";
                    lPOSCardEntry."EFT Transaction Type" := lPOSCardEntry."EFT Transaction Type"::Refund;
                end;
            else begin
                lPOSCardEntry."Transaction Type" := lPOSCardEntry."Transaction Type"::" ";
                lPOSCardEntry."EFT Transaction Type" := lPOSCardEntry."EFT Transaction Type"::Purchase;
            end;
        end;
        lPOSCardEntry.Amount := pNewLine.Amount;
        lPOSCardEntry.VAT := pNewLine."VAT Amount";
        lPOSCardEntry."Receipt No." := pNewLine."Receipt No.";
        lPOSCardEntry."Auth.code" := pPOSCardRequest."Trans Authorization";
        lPOSCardEntry."Expiry Date" := pPOSCardRequest."Card Last Date";
        lPOSCardEntry."Res.code" := pPOSCardRequest."Authorization Code";
        lPOSCardEntry.Date := TODAY;
        lPOSCardEntry.Time := TIME;
        lPOSCardEntry."Authorisation Ok" := TRUE;
        lPOSCardEntry."MSR input" := TRUE;
        lPOSCardEntry."FSN Last Digits" := pPOSCardRequest."Cast Last Numbers";
        lPOSCardEntry."Tender Type" := pNewLine.Number;
        lPOSCardEntry."EFT Terminal ID" := COPYSTR(pPOSCardRequest."Terminal ID", 1, 10);
        lPOSCardEntry."EFT Merchant No." := COPYSTR(pPOSCardRequest."Retailer ID", 1, 20);
        lPOSCardEntry."EFT Trans. Date" := pPOSCardRequest."Trans Date";
        lPOSCardEntry."EFT Trans. Time" := pPOSCardRequest."Trans Time";
        lPOSCardEntry."EFT Trans. No." := COPYSTR(pPOSCardRequest."Trans Reference", 1, 10);
        lPOSCardEntry."EFT Device Name" := pPOSCardRequest.Command;
        lPOSCardEntry."EFT Batch No." := ConvertCommandToType(pPOSCardRequest.Command);

        pKey := BOUTIL.CombineValue(5, FORMAT(pPOSCardRequest."Entry No."), FORMAT(DATE2DMY(gDateContext, 1)), FORMAT(DATE2DMY(gDateContext, 2))
                                    , FORMAT(DATE2DMY(gDateContext, 3)), pPOSCardRequest."Distribution Location");
        lPOSCardEntry."FSN Operation Name" := COPYSTR(pKey, 1, 50);

        IF NOT BINList.GET(pPOSCardRequest.BIN) THEN BEGIN
            BINList.INIT;
            BINList."BIN/IIN" := pPOSCardRequest.BIN;
            BINList."Scheme Text" := '';
            BINList."Card Type" := '';
            BINList."Bank Name" := '';
        END;
        lPOSCardEntry."FSN BIN No." := BINList."BIN/IIN";
        lPOSCardEntry."Card Type" := BINList."Card Type";
        lPOSCardEntry."Card Type Name" := BINList."Scheme Text";
        lPOSCardEntry."FSN Bank Name" := BINList."Bank Name";
        lPOSCardEntry."Extra Data" := 'ATH';
        lPOSCardEntry."Auth. Source Code" := 'KINPOS';
        lPOSCardEntry."FSN Print Amount" := lPOSCardEntry.Amount;
        lPOSCardEntry."Entry No." := NextEntryNo(pNewLine."Store No.", pNewLine."POS Terminal No.");
        if lPOSCardEntry.INSERT(TRUE) THEN;

        POSSession.SetValue('KINPOSAUTHRETURN', '');
    end;

    //PINPAD
    procedure KinposSaveErrorReadCard(var pRequestEntryTMP: Record "FSN POS Card Request Entry" temporary; pPOSLine: Record "LSC POS Trans. Line"; pTypeTransInt: Integer)
    var
        POSCardReqEntry: Record "FSN POS Card Request Entry";
    begin
        POSCardReqEntry.INIT();
        POSCardReqEntry.TRANSFERFIELDS(pRequestEntryTMP);
        POSCardReqEntry."Distribution Location" := RetailSetup."Distribution Location";
        POSCardReqEntry.VALIDATE(POSCardReqEntry."Entry No.");
        POSCardReqEntry."Authorization Code" := 'RL';
        POSCardReqEntry."Response Web Ok" := FALSE;
        POSCardReqEntry."Entity Name" := 'SERFINSA';
        POSCardReqEntry."Type Request" := POSCardReqEntry."Type Request"::POS;
        POSCardReqEntry."Receipt No." := pPOSLine."Receipt No.";
        POSCardReqEntry."Store No." := pPOSLine."Store No.";
        POSCardReqEntry."Line No." := pPOSLine."Line No.";

        POSCardReqEntry."Tender Type" := pPOSLine.Number;
        POSCardReqEntry.User := USERID;
        POSCardReqEntry.Date := CURRENTDATETIME;
        //POSCardReqEntry.Command := ConvertCommandGeneric(pTypeTransInt,POSCardReqEntry."Entry Mode");//1 BUY/VOID, 2 QRYPOINT
        POSCardReqEntry."Retailer ID" := GlobalsFSNParameters."Value Text 1";
        POSCardReqEntry."Terminal ID" := GlobalsFSNParameters."Value Text 2";

        POSCardReqEntry.INSERT(TRUE);
    end;

    //SYSTEM
    procedure GetBinList(pBIN: Code[10])
    begin

        IF NOT BINList.GET(pBIN) THEN BEGIN
            POSMenuLineTmp.RESET;
            POSMenuLineTmp.DELETEALL;
            POSMenuLineTmp.INIT;
            POSMenuLineTmp."Menu ID" := 'BINLIST';
            POSMenuLineTmp.Command := 'BINLIST';
            POSMenuLineTmp.Parameter := pBIN;
            POSMenuLineTmp.INSERT();
            CLEARLASTERROR();
            COMMIT;
            IF NOT CODEUNIT.RUN(CODEUNIT::"FSN Card External Conextion", POSMenuLineTmp) THEN;
        END;
        IF NOT BINList.GET(pBIN) THEN BEGIN
            BINList.INIT();
            BINList."BIN/IIN" := pBIN;
            BINList."Bank Name" := '';
            BINList."Tender Type Default" := '';
        END;
    end;
    //BOTH
    procedure InitPOSCardEntryByPOSTransLine(pTransLine: Record "LSC POS Trans. Line"; pHeader: Record "LSC POS Transaction"; pBatch: Code[10])
    var
        POSCardEntryNew: Record "LSC POS Card Entry";
        CardEntry: Record "LSC POS Card Entry";
        RetailUser: Record "LSC Retail User";
        eNTRY: Integer;
    begin

        RetailSetup.Get();
        POSCardEntryNew.Init();
        POSCardEntryNew."Store No." := pTransLine."Store No.";
        POSCardEntryNew."POS Terminal No." := pTransLine."POS Terminal No.";
        POSCardEntryNew."Entry No." := NextEntryNo(pTransLine."Store No.", pTransLine."POS Terminal No.");
        POSCardEntryNew."Line No." := pTransLine."Line No.";

        IF pHeader."Sale Is Return Sale" then begin
            POSCardEntryNew."Transaction Type" := POSCardEntryNew."Transaction Type"::"Void Sale";
            POSCardEntryNew."EFT Transaction Type" := POSCardEntryNew."EFT Transaction Type"::Refund;
        end else begin
            POSCardEntryNew."Transaction Type" := POSCardEntryNew."Transaction Type"::" ";
            POSCardEntryNew."EFT Transaction Type" := POSCardEntryNew."EFT Transaction Type"::Purchase;
        end;
        POSCardEntryNew.Amount := pTransLine.Amount;
        POSCardEntryNew."Receipt No." := pTransLine."Receipt No.";
        POSCardEntryNew."Tender Type" := pTransLine.Number;
        POSCardEntryNew."EFT Batch No." := pBatch;

        IF pBatch = 'PREPAYMENT' then begin
            POSCardEntryNew."EFT Device Name" := 'MANCOMPRANOR';//Default
        end;
        POSCardEntryNew.Insert();
    end;
    //BOTH
    procedure UpdatePOSCardEntryByBIN(var pPosCardEntry: Record "LSC POS Card Entry"; pBin: Code[10])
    begin
        IF NOT BINList.GET(pBIN) THEN BEGIN
            BINList.INIT();
            CLEAR(BINList);
            BINList."BIN/IIN" := pBIN;
        END;
        pPosCardEntry."Card Type" := BINList."Card Type";
        pPosCardEntry."Card Type Name" := BINList."Scheme Text";
        pPosCardEntry."Extra Data" := BINList."Extra Data";
        pPosCardEntry."FSN BIN No." := pBIN;
        if BINList."Bank Name" <> '' then
            pPosCardEntry."FSN Bank Name" := BINList."Bank Name";
    end;
    //BOTH
    procedure UpdatePOSCardEntryAuthorization(var pPosCardEntry: Record "LSC POS Card Entry"; pRequEntry: Record "FSN POS Card Request Entry")
    var
        pKey: Text;
    begin
        pPosCardEntry."Auth.code" := pRequEntry."Trans Authorization";
        pPosCardEntry."EFT Trans. Date" := pRequEntry."Trans Date";
        pPosCardEntry."EFT Trans. Time" := pRequEntry."Trans Time";
        pPosCardEntry."EFT Trans. No." := pRequEntry."Trans Reference";
        pPosCardEntry."EFT Merchant No." := pRequEntry."Retailer ID";
        pPosCardEntry."EFT Terminal ID" := CopyStr(pRequEntry."Terminal ID", 1, 10);
        pPosCardEntry."Res.code" := pRequEntry."Authorization Code";
        pPosCardEntry."Authorisation Ok" := pPosCardEntry."Res.code" = '00';
        if CopyStr(pRequEntry.Command, 1, 3) = 'MAN' then
            pPosCardEntry."Auth. Source Code" := 'PREPAYMENT'
        else
            pPosCardEntry."Auth. Source Code" := 'KINPOS';
        /*pPosCardEntry."EFT Additional ID" := '';//1601
        pPosCardEntry."Card Number" := '000000'; //Static*/
        pPosCardEntry."Expiry Date" := pRequEntry."Card Last Date";
        //pPosCardEntry."FSN CVV" := pRequEntry.CVV;
        pPosCardEntry.Date := Today;
        pPosCardEntry.Time := Time;
        pPosCardEntry."Extra Data" := 'ATH';
        pKey := BOUTIL.CombineValue(5, FORMAT(pRequEntry."Entry No."), FORMAT(DATE2DMY(pRequEntry."Date Key", 1))
                             , FORMAT(DATE2DMY(pRequEntry."Date Key", 2))
                             , FORMAT(DATE2DMY(pRequEntry."Date Key", 3)), pRequEntry."Distribution Location");
        pPosCardEntry."FSN Operation Name" := COPYSTR(pKey, 1, 50);
        pPosCardEntry."FSN Print Amount" := pPosCardEntry.Amount;

        if pRequEntry.Plazo <> '' then
            pPosCardEntry."FSN Points/Terms" := pRequEntry.Plazo;
        if pRequEntry.Points <> '' then
            pPosCardEntry."FSN Points/Terms" := pRequEntry.Points;

    end;

    procedure IsManualSetup(): Boolean
    begin
        RetailSetup.Get();
        if FSNParameter.Get('KINPOS', RetailSetup."Local Store No.") then;//Store Priority

        exit(FSNParameter.Activo and (FSNParameter.Descripcion = 'MANUAL'));
    end;
    //BOTH
    procedure IsManualSetup(var pFSNParameter: record "FSN Parameter"): Boolean
    begin
        RetailSetup.Get();
        Clear(pFSNParameter);
        if pFSNParameter.Get('KINPOS', RetailSetup."Local Store No.") then;//Store Priority

        exit(pFSNParameter.Activo and (pFSNParameter.Descripcion = 'MANUAL'));
    end;
    //SYSTEM
    procedure GetLastRecord(var pPosCardEntry: Record "LSC POS Card Entry"; pStore: Code[20]; pTerminal: Code[20]; pReceipt: Code[20]; pLine: Integer): Boolean
    begin
        pPosCardEntry.Reset();
        pPosCardEntry.SetRange("Store No.", pStore);
        pPosCardEntry.SetRange("POS Terminal No.", pTerminal);
        pPosCardEntry.SetRange("Receipt No.", pReceipt);
        pPosCardEntry.SetRange("Line No.", pLine);
        pPosCardEntry.SetRange("Authorisation Ok", true);
        if pPosCardEntry.FindFirst() then
            exit(true);
        pPosCardEntry.SetRange("Authorisation Ok");
        if pPosCardEntry.Find('+') then
            exit(true);
        exit(false);
    end;
    //SYSTEM
    procedure PrintCardVoucherRequest(pResponseEntry: Record "FSN POS Card Request Entry"; Tray: Integer; TypePrint: Integer; pErrorText: Text[100])
    var
        POSPrintUtil: Codeunit "LSC POS Print Utility";
        BINList_l: Record "FSN BIN Bank";
        POSCardEntry_l: Record "LSC POS Card Entry";
        CompanyInfo_l: Record Company;
        POSTransaction_l: Record "LSC POS Transaction";
        Store_l: Record "LSC Store";
        DSTR1: Text[100];
        _i: Integer;
        _Int: Integer;
        _NewCardText: Text[150];
        _Autho: Text[30];
        _InvoiceText: Text[30];
        _Refer: Text[30];
        _DateText: Text[30];
        _AmountText: Text[30];
        _CopyText: array[3] of Text[50];
        _Decimal: Decimal;
        _ArrText: array[2] of Text[30];
        _Amount: Decimal;
        lText001: Label 'Query Points: ';
        lText002: Label 'Points Loyalty';
        lText003: Label 'SERFINSA';
        lText004: Label 'QUERY POINTS';
        lText005: Label 'QUERY';
        lText006: Label 'Request Fail!';
        lText007: Label 'ERROR';
    begin
        pErrorText := COPYSTR(pErrorText, 1, 30);
        _i := 1;

        CompanyInfo_l.FindFirst();
        IF Store_l.GET(pResponseEntry."Store No.") THEN;

        _NewCardText := '';
        _Amount := 0;
        BINList_l.RESET;
        CLEAR(BINList_l);
        IF BINList_l.GET(pResponseEntry.BIN) THEN;

        _NewCardText := '************' + pResponseEntry."Cast Last Numbers";
        IF EVALUATE(_Amount, pResponseEntry."Amount Input") THEN
            _Amount := _Amount / 100;

        _ArrText[1] := '';
        _ArrText[2] := '';
        IF TypePrint = 2 THEN BEGIN
            _ArrText[1] := lText001;
            _CopyText[1] := lText004;

            IF EVALUATE(_Decimal, pResponseEntry.Points) THEN BEGIN
                _Decimal := _Decimal / 100;
                _ArrText[1] += FORMAT(ROUND(_Decimal, 1));
            END;
        END ELSE BEGIN
            _ArrText[1] := pErrorText;
            _CopyText[1] := lText007;
            IF pResponseEntry."Authorization Code" = '00' THEN
                _CopyText[1] := 'OK';
        END;

        _CopyText[2] := '';
        _CopyText[3] := '';
        _DateText := FORMAT(pResponseEntry.Date);
        _AmountText := '$' + FORMAT(_Amount, 0, '<Precision,2:2><Standard Format,0>');

        IF TypePrint = 2 THEN
            PrintCardVoucherLine(CompanyInfo_l, Store_l, lText003, pResponseEntry."Terminal ID", lText005, _NewCardText, pResponseEntry."Trans Authorization",
              FORMAT(_i), pResponseEntry."Trans Reference", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[_i], '', pResponseEntry."Receipt No.")
        ELSE BEGIN
            PrintCardVoucherLine(CompanyInfo_l, Store_l, lText003, pResponseEntry."Terminal ID", lText006, _NewCardText, pResponseEntry."Trans Authorization",
              FORMAT(_i), pResponseEntry."Trans Reference", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[_i], '', pResponseEntry."Receipt No.");
            IF pResponseEntry."Authorization Code" = '00' then BEGIN
                _CopyText[2] := 'COPIA';
                PrintCardVoucherLine(CompanyInfo_l, Store_l, lText003, pResponseEntry."Terminal ID", lText006, _NewCardText, pResponseEntry."Trans Authorization",
                  FORMAT(_i), pResponseEntry."Trans Reference", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[2], '', pResponseEntry."Receipt No.");
            END
        END;


    end;

    //SYSTEM
    procedure GetDecimalFromText(pValue: Text[20]) ReturnVal: Decimal
    var
        Int_: Integer;
    begin
        ReturnVal := 0;
        IF STRPOS(pValue, '.') > 0 THEN BEGIN
            IF EVALUATE(ReturnVal, pValue) THEN
                EXIT(ReturnVal);
        END ELSE BEGIN
            IF EVALUATE(Int_, pValue) THEN
                ReturnVal := Int_ / 100;
        END;
    end;
    //SYSTEM
    procedure NextEntryNo(pStore: Code[10]; pTerm: Code[10]): Integer
    var
        CardEntry: Record "LSC POS Card Entry";
        XMLRequest: Text;
        XMLResponse: Text;
        RequestID: Text[50];
        PosMenuLineTemp: Record "LSC POS Menu Line";
        Processed: Boolean;
        MsgResult: Text;
        FSNUtility: Codeunit "FSN Utility";
    begin
        //evaluar si es call y entry sea menor a 0 find firt menos 1
        RequestID := 'FSNCC';
        Processed := false;
        FSNUtility.InvokeGlobalChannel(XMLRequest, XMLResponse, RequestID, PosMenuLineTemp, Processed, MsgResult);
        CardEntry.Reset();
        CardEntry.SetRange(CardEntry."Store No.", pStore);
        CardEntry.SetRange(CardEntry."POS Terminal No.", pTerm);
        IF not Processed THEN begin
            if CardEntry.FindLast() then begin
                exit(CardEntry."Entry No." + 1)
            end else begin
                exit(1);
            end;
        end else begin
            if CardEntry.FindFirst() then begin
                exit(CardEntry."Entry No." - 1)
            end else
                exit(-1);
        end;
    end;
    //SYSTEM

    procedure PrintCardVoucher(var POSCardEntry: Record "LSC POS Card Entry"; Receipt: Code[20]; IsCopy: Boolean; IsRegister: Boolean; var Tray: Integer)
    var
        /*POSCardEntry: Record "LSC POS Card Entry";*/
        CompanyInfo_l: Record "Company";
        Store_l: Record "LSC Store";
        POSPaymentLine: Record "LSC POS Trans. Line";
        _CardText: Text[100];
        BINList_l: Record "FSN BIN Bank";
        _ArrText: array[3] of Text[100];
        _CopyText: array[3] of Text[100];
        _NewCardText: Text[100];
        _DateText: Text[100];
        _AmountText: Text[100];
        VCardTransLine: Record "LSC POS Trans. Line";
        controler: Codeunit "FSN POS Card Controller";
        VTenderTypeSetup: Record "LSC Tender Type Setup";
        POSCardIntegration: Codeunit "FSN POS Card Integration";
    begin//28981


        Clear(POSCardEntry);
        POSCardEntry.SetCurrentKey("Store No.", "POS Terminal No.", "Receipt No.", "Line No.");
        POSCardEntry.setrange(POSCardEntry."Receipt No.", Receipt);
        POSCardEntry.SetRange("Authorisation Ok", true);
        if not POSCardEntry.FindFirst() then
            exit;

        CompanyInfo_l.Get('FASANI');
        Clear(Store_l);
        if Store_l.Get(POSCardEntry."Store No.") then;
        repeat
            if POSPaymentLine.Get(POSCardEntry."Receipt No.", POSCardEntry."Line No.") and (POSPaymentLine."Entry Status" = 0) then begin //WVILLALTA 11.20-
                _CardText := '';
                BINList_l.Reset();
                Clear(BINList_l);
                if BINList_l.GET(POSCardEntry."FSN BIN No.") then;

                _ArrText[1] := 'COMPRA';
                _ArrText[2] := '';
                if (POSCardEntry.Amount < 0) OR (POSCardEntry."FSN Print Amount" < 0) then
                    _ArrText[1] := 'ANULACION';

                _NewCardText := '****-****-***-' + POSCardEntry."FSN Last Digits";
                _CopyText[1] := 'Copia Cliente';
                _CopyText[2] := 'Copia Comercio';                                                                                          //WVILLALTA 11.20+
                _CopyText[3] := 'Copia Comercio';
                _DateText := POSCardEntry."EFT Trans. Date" + '-' + POSCardEntry."EFT Trans. Time";

                if POSCardEntry."FSN Print Amount" <> 0 then
                    _AmountText := '$' + Format(POSCardEntry."FSN Print Amount", 0, '<Precision,2:2><Standard Format,0>')
                else
                    _AmountText := '$' + Format(POSCardEntry.Amount, 0, '<Precision,2:2><Standard Format,0>');

                PrintCardVoucherLine(CompanyInfo_l, Store_l, 'SERFINSA', POSCardEntry."EFT Terminal ID", FORMAT(POSCardEntry."Transaction Type"), _NewCardText,
                  POSCardEntry."Auth.code", '1', POSCardEntry."EFT Trans. No.", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[1], '', POSCardEntry."Receipt No.");

                PrintCardVoucherLine(CompanyInfo_l, Store_l, 'SERFINSA', POSCardEntry."EFT Terminal ID", FORMAT(POSCardEntry."Transaction Type"), _NewCardText,
                  POSCardEntry."Auth.code", '2', POSCardEntry."EFT Trans. No.", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[2], '', POSCardEntry."Receipt No.");
            end;
        until POSCardEntry.NEXT = 0;
    end;

    procedure PrintCardVoucherLine(pCompany: Record Company; pStore: Record "LSC Store"; pFromEmisor: Text[30]; pTerminal: Text[30]; pSalesType: Text[30]; pCard: Text[30]; pAuthorization: Text[30]; pDocumentNo: Text[30]; pRef: Text[30]; pDateText: Text[30]; pAmountText: Text[30]; pAddText1: array[2] of Text[40]; pScheme: Text[30]; pCopyText: Text[30]; pImg: Text[250]; pReceipt: Code[20])
    var
        DSTR1: Text[100];
        Tray: Integer;
        Grand: Boolean;
        Value: array[10] of Text;
        NodeName: array[10] of Text;
        PrintUtility: Codeunit "LSC POS Print Utility";
    begin
        //PrintCardVoucherLine
        //WVILLALTA26SEPT19-
        IF NOT PrintUtility.OpenReceiptPrinter(2, 'PREPOST', '', 0, pReceipt) THEN
            EXIT;
        Tray := 2;
        DSTR1 := COPYSTR('#C######################################', 1);

        Value[1] := pCompany.Name;
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := pStore.Name;
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := pStore.Address;
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        Value[1] := pStore."Address 2";
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := '';
        Value[2] := '';
        //PrintLine(Tray,FormatLine(PrintUtility.FormatStr(Value,DSTR1),FALSE,FALSE,FALSE,FALSE));//Blank

        DSTR1 := '#L################## #R##################';
        Value[1] := 'Recibo ID';
        NodeName[1] := 'Recibo';
        Value[2] := pReceipt;
        NodeName[2] := 'ReciboNo';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := 'Terminal ID';
        NodeName[1] := 'Terminal';
        Value[2] := pTerminal;
        NodeName[2] := 'TerminalNo';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IF POSSESSION.TerminalNo() <> '' THEN BEGIN
            Value[1] := 'Caja ID';
            NodeName[1] := 'Caja';
            Value[2] := POSSESSION.TerminalNo();
            NodeName[2] := 'Caja No';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := pSalesType;
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        IF pAddText1[1] <> '' THEN BEGIN
            Value[1] := pAddText1[1];
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        IF pAddText1[2] <> '' THEN BEGIN
            Value[1] := pAddText1[2];
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;

        DSTR1 := '#L################## #R##################';
        Value[1] := pFromEmisor;
        NodeName[1] := 'Emisor';
        Value[2] := pCard;
        NodeName[2] := 'Card';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := '';
        Value[2] := '';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//Blank

        Value[1] := STRSUBSTNO('AUT: %1', pAuthorization);
        NodeName[1] := 'Aut';
        Value[2] := '';
        NodeName[2] := '';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, TRUE, FALSE, FALSE));

        Value[1] := STRSUBSTNO('REF: %1', pRef);
        NodeName[1] := 'Ref';
        Value[2] := pDateText;
        NodeName[2] := 'Date';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        Value[1] := '';
        Value[2] := '';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//Blank

        DSTR1 := '#L##### #R########';

        Value[1] := 'MONTO';
        Value[2] := pAmountText;
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), TRUE, TRUE, FALSE, FALSE));//Bold - High

        Value[1] := '';
        Value[2] := '';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//Blank

        IF (pDocumentNo = '2') AND NOT (pTerminal = '00241940') THEN BEGIN//Only Commerce not terminal E-Commerce WVILLALTA27MAR2020
            DSTR1 := COPYSTR('#L######################################', 1);
            Value[1] := ''; //WVILLALTA17MAR2020-
            Value[2] := '';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//WVILLALTA17MAR2020+
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//WVILLALTA17MAR2020+

            Value[1] := 'Firma___________________________';
            Value[2] := '';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
            Value[1] := '';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//Blank
            Value[1] := 'DUI.____________________________';
            Value[2] := '';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        END;
        Value[1] := '';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));//Blank

        DSTR1 := '#L########## #C############ #R##########';
        Value[1] := '===========';

        IF pScheme <> '' THEN
            Value[2] := pScheme
        ELSE
            Value[2] := '';

        Value[3] := '===========';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));

        DSTR1 := COPYSTR('#C######################################', 1);
        Value[1] := pCopyText;
        Grand := pDocumentNo = '3';
        PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), FALSE, Grand, Grand, FALSE));
        IF Grand THEN BEGIN
            DSTR1 := COPYSTR('#C##################', 1);
            Value[1] := '####################';
            PrintUtility.PrintLine(Tray, PrintUtility.FormatLine(PrintUtility.FormatStr(Value, DSTR1), TRUE, TRUE, TRUE, FALSE));
        END;
        IF NOT PrintUtility.ClosePrinter(2) THEN
            EXIT;
    end;

    //SYSTEM
    procedure PrintCardEntryReport(pDate: Date; pTermina: Code[10]; Tray: Integer)
    var
        Company: Record Company;
        Store: Record "LSC Store";
        lPOSTerminal: Record "LSC POS Terminal";
        POSCardEntry: Record "LSC POS Card Entry";
        POSCardRequestEntryRows: Record "FSN POS Card Request Entry";
        POSCardRequestEntryRows2: Record "FSN POS Card Request Entry";
        QryPOSCardEntries: Query "FSN POS Card Report";
        TransHdr: Record "LSC Transaction Header";
        TransTypeText: array[5] of Text[20];
        Quantitys: array[5] of Integer;
        Amounts: array[5] of Decimal;
        Value: array[10] of Text;
        DSTR1: Text[100];
        DSTR2: Text[100];
        DSTR3: Text[100];
        AmountDecimal: Decimal;
        AmountText: Text[12];
        _TypeTrans: Text[20];
        _i: Integer;
    begin
        Tray := 2;
        IF NOT (lPOSTerminal.GET(pTermina)) THEN
            EXIT;
        IF NOT (Store.GET(lPOSTerminal."Store No.")) THEN
            EXIT;
        if not Company.Get('FASANI') then
            Company.FindFirst();
        RetailSetup.GET();
        IF NOT POSPrintUtil.OpenReceiptPrinter(Tray, 'PREPOST', '', 0, pTermina) THEN
            EXIT;

        DSTR2 := COPYSTR('#C######################################', 1);
        DSTR1 := '#L################## #R##################';
        DSTR3 := '#L########## #C############ #R##########';
        Value[1] := 'SERFINSA';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, TRUE, TRUE, FALSE));//Grand
        Value[1] := Company.Name;
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := Store.Name;
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := 'Fecha: ' + FORMAT(pDate);
        Value[2] := 'Hora: ' + FORMAT(TIME);
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR1), FALSE, FALSE, FALSE, FALSE));
        Value[1] := 'REPORTE DE AUDITORIA';
        Value[2] := '';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := 'CAJA - ' + lPOSTerminal."No.";
        Value[2] := '';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := '========================================';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := 'TARJETA';
        Value[2] := 'BANCO';
        Value[3] := 'AUT.';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
        Value[1] := 'FECHA';
        Value[2] := 'TIPO COMPRA';
        Value[3] := 'HORA';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
        Value[1] := '';
        Value[2] := '';
        Value[3] := 'TOTAL';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
        Value[1] := '========================================';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));

        TransTypeText[1] := 'TOT. COMPRA NORMAL :';
        TransTypeText[2] := 'TOT. EN PUNTOS :';
        TransTypeText[3] := 'TOT. A PLAZO :';
        TransTypeText[4] := 'TOT. DEVOL. :';
        TransTypeText[5] := 'TOTAL GLOBAL :';

        CLEAR(QryPOSCardEntries);
        QryPOSCardEntries.SETRANGE(QryPOSCardEntries.Date, pDate);
        QryPOSCardEntries.SETRANGE(QryPOSCardEntries.POS_Terminal_No, pTermina);
        QryPOSCardEntries.OPEN();
        WHILE QryPOSCardEntries.READ() DO BEGIN
            IF ((QryPOSCardEntries.Transaction_Type = QryPOSCardEntries.Transaction_Type::Offline) AND
              (QryPOSCardEntries.MSR_input) AND (QryPOSCardEntries.Authorisation_Ok))
              OR (QryPOSCardEntries.Nombre_Tarjeta = 'WOMPI') THEN BEGIN

                IF TransHdr.GET(QryPOSCardEntries.Store_No, QryPOSCardEntries.POS_Terminal_No, QryPOSCardEntries.Transaction_No)
                  AND NOT TransHdr."Sale Is Return Sale"
                  AND (TransHdr."Retrieved from Receipt No." = '')
                  AND (TransHdr."Refund Receipt No." = '')
                THEN BEGIN


                    Value[1] := '***' + QryPOSCardEntries.Ultimos_Digitos;
                    Value[2] := COPYSTR(QryPOSCardEntries.Nombre_Tarjeta, 1, 20);
                    Value[3] := QryPOSCardEntries.Auth_code;
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := FORMAT(QryPOSCardEntries.Date_CardEntry);
                    Value[2] := QryPOSCardEntries.EFT_Batch_No;
                    _TypeTrans := Value[2];//Type
                    IF _TypeTrans = '' THEN BEGIN
                        _TypeTrans := 'NORMAL';
                        Value[2] := _TypeTrans;
                    END;
                    Value[3] := FORMAT(QryPOSCardEntries.Time);
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '';
                    Value[2] := '';
                    Value[3] := '$' + FORMAT(QryPOSCardEntries.Amount, 0, '<Precision,2:2><Standard Format,0>');
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '........................................';
                    Value[3] := '';
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
                    CASE _TypeTrans OF
                        'NORMAL':
                            BEGIN
                                Quantitys[1] += 1;
                                Amounts[1] += QryPOSCardEntries.Amount;
                            END;
                        'PUNTOS':
                            BEGIN
                                Quantitys[2] += 1;
                                Amounts[2] += QryPOSCardEntries.Amount;
                            END;
                        'PLAZOS':
                            BEGIN
                                Quantitys[3] += 1;
                                Amounts[3] += QryPOSCardEntries.Amount;
                            END;
                        'DEVOL':
                            BEGIN
                                Quantitys[4] += 1;
                                Amounts[4] += QryPOSCardEntries.Amount;
                            END;
                    END;
                    Quantitys[5] += 1;
                    IF _TypeTrans = 'DEVOL' THEN
                        Amounts[5] -= QryPOSCardEntries.Amount
                    ELSE
                        Amounts[5] += QryPOSCardEntries.Amount;
                END;
            END;
        END;
        QryPOSCardEntries.CLOSE();
        //WVILLALTA15ENE2020-
        POSCardRequestEntryRows.RESET;
        POSCardRequestEntryRows.SETCURRENTKEY("Entry No.", "Date Key", "Distribution Location");
        POSCardRequestEntryRows.SETRANGE(POSCardRequestEntryRows."Date Key", pDate);
        IF POSCardRequestEntryRows.FINDSET THEN
            REPEAT
                IF POSCardRequestEntryRows."Response Web Ok" and (UserId = POSCardRequestEntryRows.User) THEN BEGIN
                    AmountDecimal := 0;
                    IF POSCardRequestEntryRows."Amount Input" <> '' THEN BEGIN
                        IF EVALUATE(AmountDecimal, POSCardRequestEntryRows."Amount Input") THEN
                            AmountDecimal := AmountDecimal / 100;
                    END;
                    IF AmountDecimal = 0 THEN
                        IF POSCardRequestEntryRows."Void Number" <> 0 THEN
                            IF POSCardRequestEntryRows2.GET(POSCardRequestEntryRows."Void Number", POSCardRequestEntryRows."Void Date Key", POSCardRequestEntryRows."Void Dist. Location") THEN
                                IF POSCardRequestEntryRows2."Amount Input" <> '' THEN
                                    IF EVALUATE(AmountDecimal, POSCardRequestEntryRows2."Amount Input") THEN
                                        AmountDecimal := AmountDecimal / 100;

                    Value[1] := '***' + POSCardRequestEntryRows."Cast Last Numbers";
                    Value[2] := COPYSTR(POSCardRequestEntryRows."Bank Name", 1, 20);
                    Value[3] := POSCardRequestEntryRows."Trans Authorization";
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := FORMAT(POSCardRequestEntryRows."Date Key");
                    Value[2] := ConvertCommandToType(POSCardRequestEntryRows.Command);
                    _TypeTrans := Value[2];//Type
                    IF _TypeTrans = '' THEN BEGIN
                        _TypeTrans := 'NORMAL';
                        Value[2] := _TypeTrans;
                    END;
                    Value[3] := FORMAT(DT2TIME(POSCardRequestEntryRows.Date));//Time
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '';
                    Value[2] := '';
                    Value[3] := '$' + FORMAT(AmountDecimal, 0, '<Precision,2:2><Standard Format,0>');
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
                    Value[1] := '........................................';
                    Value[3] := '';
                    POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
                    CASE _TypeTrans OF
                        'NORMAL':
                            BEGIN
                                Quantitys[1] += 1;
                                Amounts[1] += AmountDecimal;
                            END;
                        'PUNTOS':
                            BEGIN
                                Quantitys[2] += 1;
                                Amounts[2] += AmountDecimal;
                            END;
                        'PLAZOS':
                            BEGIN
                                Quantitys[3] += 1;
                                Amounts[3] += AmountDecimal;
                            END;
                        'DEVOL':
                            BEGIN
                                Quantitys[4] += 1;
                                Amounts[4] += AmountDecimal;
                            END;
                    END;
                    Quantitys[5] += 1;
                    IF _TypeTrans = 'DEVOL' THEN
                        Amounts[5] -= AmountDecimal
                    ELSE
                        Amounts[5] += AmountDecimal;

                END;
            UNTIL POSCardRequestEntryRows.NEXT = 0;
        Value[1] := '========================================';
        Value[3] := '';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        Value[1] := '*** TOTALES ***';
        POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
        FOR _i := 1 TO ARRAYLEN(TransTypeText) DO BEGIN
            IF _i = 5 THEN BEGIN
                Value[1] := '........................................';
                Value[2] := '';
                Value[3] := '';
                POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR2), FALSE, FALSE, FALSE, FALSE));
            END;
            Value[1] := TransTypeText[_i];
            Value[2] := FORMAT(Quantitys[_i]);
            Value[3] := '$' + FORMAT(Amounts[_i], 0, '<Precision,2:2><Standard Format,0>');
            POSPrintUtil.PrintLine(Tray, POSPrintUtil.FormatLine(POSPrintUtil.FormatStr(Value, DSTR3), FALSE, FALSE, FALSE, FALSE));
        END;

        IF NOT POSPrintUtil.ClosePrinter(Tray) THEN
            EXIT;
    end;

    local procedure PrintCardVoucherRequest(Transaction: Record "LSC transaction Header"; Receipt: Code[20]; IsCopy: Boolean; IsRegister: Boolean; Tray: Integer)
    var
        BINlist_l: Record "FSN BIN Bank";
        POSCardRequest_l: Record "FSN POS Card Request Entry";
        POSCardEntry_l: Record "LSC POS Card Entry";
        CompanyInfo_l: Record "Company";
        Store_l: Record "LSC Store";
        DSTR1: Text[100];
        _i: Integer;
        _Int: integer;
        _NewCardText: Text[100];
        _Autho: Text[30];
        _InvoiceText: Text[30];
        _Refer: Text[30];
        _DateText: Text[30];
        _AmountText: Text[30];
        _CopyText: array[3] of Text[50];
        _Decimal: Decimal;
        _ArrText: array[2] of Text[30];
        _Amount: Decimal;
    begin
        CompanyInfo_l.GET('FASANI');
        if IsRegister then begin

            if Store_l.GET(Transaction."Store No.") then;

            POSCardRequest_l.Reset();
            POSCardRequest_l.SetCurrentKey("Receipt No.", "Line No.", "Cast Last Numbers", "Enter Input", "Response Web Ok");
            if not IsCopy then                                            //WVILLALTA05JUN2020-
                POSCardRequest_l.SetRange(POSCardRequest_l."Line No.", Tray);//WVILLALTA05JUN2020+
            POSCardRequest_l.SetRange(POSCardRequest_l."Receipt No.", Transaction."Receipt No.");
            POSCardRequest_l.SetRange(POSCardRequest_l."Response Web Ok", TRUE);
            if POSCardRequest_l.FindFirst() then
                REPEAT
                    _NewCardText := '';
                    _Amount := 0;
                    BINList_l.Reset();
                    Clear(BINList_l);
                    if BINList_l.GET(POSCardRequest_l.BIN) then;
                    _NewCardText := '************' + POSCardRequest_l."Cast Last Numbers";
                    if Evaluate(_Amount, POSCardRequest_l."Amount Input") then
                        _Amount := _Amount / 100;

                    _ArrText[1] := '';
                    _ArrText[2] := '';
                    if Transaction."Sale Is Return Sale" then begin
                        _ArrText[1] := 'ANULACION';
                        if _Amount > 0 then
                            _Amount := -_Amount;
                    end else
                        if POSCardRequest_l.Points <> '' then begin
                            _ArrText[1] := 'Puntos Lealtad: ';
                            if Evaluate(_Decimal, POSCardRequest_l.Points) then begin
                                _Decimal := _Decimal / 100;
                                _ArrText[1] += FORMAT(ROUND(_Decimal, 1));
                            end;
                        end else
                            if POSCardRequest_l.Command in ['MANCOMPRAMIL', 'BANCOMPRAMIL', 'EMVCOMPRAMIL'] then begin//WVILLALTA 06.21-
                                _ArrText[1] := 'Puntos Lealtad: ';
                                if Evaluate(_Decimal, POSCardRequest_l."Amount Input") then begin
                                    _ArrText[1] += Format(Round(_Decimal, 1));
                                end;                                                                                            //WVILLALTA 06.21+
                            end else
                                if POSCardRequest_l.Plazo <> '' then
                                    _ArrText[2] := 'Compra a Plazo :' + POSCardRequest_l.Plazo + ' Meses';

                    _CopyText[1] := 'Copia Cliente';
                    _CopyText[2] := 'Copia Comercio';
                    _CopyText[3] := 'Copia Comercio';
                    _DateText := FORMAT(POSCardRequest_l.Date);
                    _AmountText := '$' + FORMAT(_Amount, 0, '<Precision,2:2><Standard Format,0>');
                    FOR _i := 1 TO 2 DO BEGIN//Copy max 3
                        //diferencia de tabla
                        PrintCardVoucherLine(CompanyInfo_l, Store_l, 'SERFINSA', POSCardRequest_l."Terminal ID", 'VENTA', _NewCardText, POSCardRequest_l."Trans Authorization",
                            FORMAT(_i), POSCardRequest_l."Trans Reference", _DateText, _AmountText, _ArrText, BINList_l."Scheme Text", _CopyText[_i], '', POSCardRequest_l."Receipt No.");
                    END;
                until POSCardRequest_l.NEXT = 0;
        end;
    end;

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
        POStrans: Record "LSC transaction Header";
        tray: Integer;
        POSCardE: Record "LSC POS Card Entry";
        PosCardReq: Record "FSN POS Card Request Entry";
    begin
        if RequestID = 'PRINTCARDVOUCHER' then begin
            tray := 2;
            PrintCardVoucher(POSCardE, XMLRequest, false, false, tray);
            Processed := TRUE;
        end;

        if RequestID = 'NULLPOSCARDENTRY' then begin
            if Page.RunModal(Page::"FSN POS Card Request Entries", PosCardReq) = Action::LookupOK then begin
            end;
        end;
    end;

    //process wompi integration
    procedure Post(Uri: Text; request: HttpRequestMessage; var CodeResult: Integer): JsonObject;
    var
        client: HttpClient;
        response: HttpResponseMessage;
        content: HttpContent;
        status: Integer;
        res: Text;
        jResponse: JsonObject;
    begin
        CodeResult := 0;
        request.Method := 'POST';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        status := response.HttpStatusCode;
        if status = 200 then begin
            content.ReadAs(res);
            jResponse.ReadFrom(res);
            CodeResult := status;
            exit(jResponse);
        end;
        CodeResult := status;
    end;
}
