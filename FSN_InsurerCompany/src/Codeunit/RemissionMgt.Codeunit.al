codeunit 50022 "FSN Remission Mgt."
{
    trigger OnRun()
    begin
        //Remission
        CASE GlobalRequestID OF
            'FSN_SEND_REMISSION':
                ProcessingRemissionTempTables();
            'FSN_GET_NEW_INSURED':
                ProcessingInsuredTempTables();
            'FSN_POST_REMISSION':
                ProcessingPostRemission();
            'FSN_RETURN_STATUS_REMISSION':
                ProcessingReturnStatus();
            'FSN_VOID_REMISSION':
                ProcessingVoidRemission();
        END;
    end;

    var
        RetailSetup: Record "LSC Retail Setup";
        RetailUser: Record "LSC Retail User";
        RemissionReport: Report "FSN Remission";
        RemissionHeaderTmp: Record "FSN Remission Header" temporary;
        RemissionLineTmp: Record "FSN Remission Line" temporary;
        InsuredLinkTmp: Record "FSN Insured Links" temporary;
        RemissionHeader: Record "FSN Remission Header";
        RemissionLine: Record "FSN Remission Line";
        InsuredLink: Record "FSN Insured Links";
        Barcodes: Record "LSC Barcodes";
        Text001: Label 'Cant be change status %1 to %2';
        Text002: Label 'Is already Released. Actual Status %1';
        Text003: Label '%1 cant by empty';
        Text004: Label '%1 not exists. Value %2';
        Text005: Label 'Company %1 is not configured for %2';
        Text006: Label 'There is nothing to register';
        Text007: Label 'Line quantity zero (0) exists. Item %1';
        Text008: Label 'No. of Remission header cant be %1 in Action = Add';
        Text009: Label 'Cant be create %1. Value %2';
        Text010: Label '%1 alredy exists. Values %2 %3 %4';
        Text011: Label 'Field %1 cant be empty';
        Text012: Label 'In status pending cant return status';
        Text013: Label 'Staff %1 not exists';
        Text015: Label 'Remission cant be higher to $%1 . According Setup company';
        Text016: Label 'Remission cant be less to $%1. According setup Company';
        Text017: Label 'You have a pending document due %1 create date %2';
        REMISSION: Code[20];
        GlobalAction: Text[30];
        GlobalRequestID: Text[50];
        Staff: Record "LSC Staff";

    procedure InitializeGlobals()
    begin
        Clear(RetailUser);
        if not RetailUser.Get(UserId) then
            RetailUser.Init();

        RetailSetup.GET;
        if RetailUser."Store No." <> '' then
            RetailSetup."Local Store No." := RetailUser."Store No.";
    end;


    procedure NewRemission(): Code[20]
    var
        lRemissionHeader: Record "FSN Remission Header";
    begin
        InitializeGlobals;

        RemissionHeader.INIT();
        RemissionHeader."Store No." := RetailSetup."Local Store No.";
        RemissionHeader.INSERT(TRUE);
        EXIT(RemissionHeader."No.");
    end;


    procedure GetRemissionAmount(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);
        lRemission.CALCFIELDS(lRemission.Amount);
        EXIT(lRemission.Amount);
    end;


    procedure GetRemissionVATAmount(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);
        lRemission.CALCFIELDS(lRemission.Amount, lRemission."Amount Including VAT");
        EXIT(lRemission."Amount Including VAT" - lRemission.Amount);
    end;


    procedure GetRemissionAmountIncVAT(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);
        lRemission.CALCFIELDS(lRemission."Amount Including VAT");
        EXIT(lRemission."Amount Including VAT");
    end;


    procedure GetRemissionTotalCompanyInsure(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);
        IF lRemission.Status <> lRemission.Status::Pending THEN BEGIN
            lRemission.CALCFIELDS(lRemission."Amount Including VAT", lRemission."Coinsurance Value", lRemission."Deductible Amount");
            EXIT(lRemission."Amount Including VAT" - lRemission."Coinsurance Value" - lRemission."Deductible Amount");
        END ELSE BEGIN
            lRemission.CALCFIELDS(lRemission."Amount Including VAT");
            EXIT(lRemission."Amount Including VAT" - GetRemissionCoinsurance(DocumentType, No) - GetRemissionManualDeductible(DocumentType, No));
        END;
    end;


    procedure GetRemissionCoinsurance(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
        lCoinsurance: Record "FSN Coinsurance";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);

        IF lRemission.Status <> lRemission.Status::Pending THEN BEGIN
            lRemission.CALCFIELDS(lRemission."Coinsurance Value");
            EXIT(lRemission."Coinsurance Value");
        END ELSE
            IF (lRemission."Coinsurance No." <> '') AND lCoinsurance.GET(lRemission."Coinsurance No.") THEN BEGIN
                lRemission.CALCFIELDS(lRemission."Amount Including VAT");
                EXIT(ROUND(((lRemission."Amount Including VAT" - lRemission."Deductible Manual") * (100 - lCoinsurance."Percent Benefit")) / 100, 0.01));
            END;

        EXIT(0);
    end;


    procedure GetRemissionComission(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
        lCompany: Record "FSN Company Insurer";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);

        IF lRemission.Status <> lRemission.Status::Pending THEN BEGIN
            lRemission.CALCFIELDS(lRemission.Comission);
            EXIT(lRemission.Comission);
        END ELSE BEGIN
            IF NOT lRemission."Comission Apply" THEN
                EXIT(0)
            ELSE
                IF lCompany.GET(lRemission."Company No.") THEN
                    EXIT(lCompany.Comission);
        END;

        EXIT(0);
    end;

    procedure verifyValidation(remission: Record "FSN Remission Header"; var pError: Boolean; var pTextError: Text)
    var
        company: Record "FSN Company Insurer";
    begin
        if not company.Get(remission."Company No.") then begin
            pError := TRUE;
            pTextError := STRSUBSTNO(Text004, company.TABLECAPTION, remission."Company No.");
            exit;
        end;

        //?verificar si se debe validar el numero de autorizacion
        if company."Validate Auth No." <> company."Validate Auth No."::"No Validation" then
            //TODO: llamar funcion
            validateAuthNo(remission."Authorization No.", company."Validate Auth No.", pError, pTextError);
    end;


    procedure GetRemissionTotalInsured(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);

        IF lRemission.Status <> lRemission.Status::Pending THEN BEGIN
            lRemission.CALCFIELDS(lRemission.Comission, lRemission."Coinsurance Value", lRemission."Deductible Amount");
            EXIT(lRemission.Comission + lRemission."Coinsurance Value" + lRemission."Deductible Amount");
        END ELSE BEGIN
            EXIT((GetRemissionComission(DocumentType, No) + GetRemissionCoinsurance(DocumentType, No) + GetRemissionManualDeductible(DocumentType, No)));
        END;
    end;


    procedure GetRemissionManualDeductible(DocumentType: Integer; No: Code[20]): Decimal
    var
        lRemission: Record "FSN Remission Header";
    begin
        IF NOT lRemission.GET(DocumentType, No) THEN
            EXIT(0);
        IF lRemission.Status <> lRemission.Status::Pending THEN BEGIN
            lRemission.CALCFIELDS(lRemission."Deductible Amount");
            EXIT(lRemission."Deductible Amount");
        END ELSE
            EXIT(lRemission."Deductible Manual");
    end;


    procedure PostRemission(var Remission: Record "FSN Remission Header"; var pError: Boolean; var pTextError: Text)
    var
        lCompany: Record "FSN Company Insurer";
        lRemissionLine: Record "FSN Remission Line";
        lInsuredLink: Record "FSN Insured Links";
        Remision_l: Record "FSN Remission Header";
        FSNParameter_l: record "FSN Parameter";
        i: Integer;
        _Date: Date;
        FSNCompanyInsurer: Record "FSN Company Insurer";
    begin
        pError := FALSE;
        pTextError := '';
        IF Remission.Status <> Remission.Status::Pending THEN BEGIN
            pError := TRUE;
            pTextError := STRSUBSTNO(Text002, FORMAT(Remission.Status));
        END;

        pError := FALSE;
        pTextError := '';
        verifyValidation(Remission, pError, pTextError);
        IF pError THEN
            ERROR(pTextError);

        //Test week document
        i := 0;
        Remision_l.RESET;
        Remision_l.SETCURRENTKEY(Status, "Sales Staff", "Create Date");
        Remision_l.SETRANGE(Remision_l.Status, Remision_l.Status::Pending);
        if FSNParameter_l.Get('REMISSION', 'LASTDATE') then
            if Evaluate(i, FSNParameter_l.Valor) then
                if i > 0 then begin
                    _Date := TODAY - i;
                    Remision_l.SETFILTER(Remision_l."Create Date", '<=%1', _Date);
                    IF Remision_l.Find('-') AND (Remision_l."Create Date" > _Date) THEN BEGIN
                        //pError := TRUE;
                        //pTextError := STRSUBSTNO(Text017, RemissionHeader."No.", RemissionHeader."Create Date");
                        //_No := RemissionHeader."No.";
                        Remision_l.DELETEALL(TRUE);
                        /*"Store No." := RetailSetup."Local Store No.";
                        "No." := _No;*/
                    END;
                end;

        /*IF "No." = '' THEN BEGIN
            FasaniSetup.GET(RetailSetup."Local Store No.");
            "No." := SeriesManager.GetNextNo(FasaniSetup."No. Series Remission", TODAY, TRUE);
            "No. Series" := FasaniSetup."No. Series Remission";
            "Store No." := RetailSetup."Local Store No.";
            
        END;*/

        IF Remission."External Document No." = '' THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("External Document No."));

        IF Remission."Sales Staff" = '' THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Sales Staff"));


        IF NOT lCompany.GET(Remission."Company No.") THEN
            pTextError := STRSUBSTNO(Text004, lCompany.TABLECAPTION, Remission."Company No.");

        IF lCompany."Maximum Value" > 0 THEN
            IF GetRemissionAmountIncVAT(Remission."Document Type", Remission."No.") > lCompany."Maximum Value" THEN
                ERROR(STRSUBSTNO(Text015, FORMAT(lCompany."Maximum Value")));

        IF lCompany."Minimum Value" > 0 THEN
            IF GetRemissionAmountIncVAT(Remission."Document Type", Remission."No.") < lCompany."Minimum Value" THEN
                ERROR(STRSUBSTNO(Text016, FORMAT(lCompany."Minimum Value")));

        IF lCompany."Pre Authorize Require" AND (Remission."Pre Authorization No." = '') THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Pre Authorization No."));

        IF lCompany."Authorize Require" AND (Remission."Authorization No." = '') THEN
            pTextError := STRSUBSTNO(Text003, Remission.FIELDCAPTION("Authorization No."));

        IF NOT lCompany."Deductible Manual" AND (Remission."Deductible Manual" <> 0) THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", Remission.FIELDCAPTION("Deductible Manual"));

        IF Remission."Deductible Manual" <> 0 THEN
            Remission.VALIDATE("Deductible Manual");

        Remission.VALIDATE("Insured Card No.");

        IF (lCompany."Item No. Deductible" = '') AND (Remission."Deductible Manual" <> 0) THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", Remission.FIELDCAPTION("Deductible Manual"));

        IF (lCompany."Coinsurance No." <> Remission."Coinsurance No.") AND NOT lCompany."Coinsurance Manual" THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", lCompany.FIELDCAPTION("Coinsurance Manual"));

        IF (lCompany.Comission <> 0) AND (lCompany."Item No. Comission" = '') THEN
            pTextError := STRSUBSTNO(Text005, lCompany."No.", lCompany.FIELDCAPTION(Comission));

        IF pTextError = '' THEN BEGIN
            lRemissionLine.RESET;
            lRemissionLine.SETRANGE(lRemissionLine."Document Type", Remission."Document Type");
            lRemissionLine.SETRANGE(lRemissionLine."Document No.", Remission."No.");
            lRemissionLine.SETRANGE(lRemissionLine.Type, lRemissionLine.Type::Item);
            IF NOT lRemissionLine.FINDFIRST THEN
                pTextError := Text006
            ELSE
                REPEAT
                    IF lRemissionLine.Quantity = 0 THEN BEGIN
                        pTextError := STRSUBSTNO(Text007, lRemissionLine.Description);
                        pError := TRUE;
                    END;
                    lRemissionLine.VALIDATE(lRemissionLine."Replication Counter");
                    lRemissionLine.MODIFY;
                UNTIL (lRemissionLine.NEXT = 0) OR pError;
        END;

        pError := pTextError <> '';
        IF pError THEN
            EXIT;

        IF FSNCompanyInsurer.Get(Remission."Company No.") AND (FSNCompanyInsurer.Policy = 'CERRADO') THEN begin
            Remission."Posting Date" := TODAY;
            Remission.Status := Remission.Status::Exclude;
            exit;
        end;

        IF (Remission."Coinsurance No." <> '') AND (GetRemissionCoinsurance(Remission."Document Type", Remission."No.") > 0) THEN
            InsertCoinsurance(Remission, lCompany);

        IF Remission."Deductible Manual" <> 0 THEN
            InsertDeductible(Remission, lCompany);

        IF (lCompany.Comission <> 0) AND (GetRemissionComission(Remission."Document Type", Remission."No.") > 0) THEN
            InsertComission(Remission, lCompany);


        SetStatus(Remission, 1, pError, pTextError);
        //COMMIT;
        //PrintRemission(Remission);
        SendRemissionToMH(Remission);
    end;


    procedure PrintRemission(Remission: Record "FSN Remission Header")
    var
        Remission2: Record "FSN Remission Header";
    begin

        CLEAR(Remission2);
        Remission2.RESET;
        Remission2.SETCURRENTKEY("Document Type", "No.");
        Remission2.SETRANGE(Remission2."Document Type", Remission."Document Type");
        Remission2.SETRANGE(Remission2."No.", Remission."No.");

        REPORT.RUNMODAL(REPORT::"FSN Remission", FALSE, TRUE, Remission2);
        //RemissionReport.SETTABLEVIEW(Remission2);
        //RemissionReport.RUN;
    end;


    procedure PrintViewRemission(Remission: Record "FSN Remission Header")
    var
        Remission2: Record "FSN Remission Header";
        ReportRemission: Report "FSN Remission";
    begin
        IF Remission.Status IN [Remission.Status::Pending, Remission.Status::Voided] THEN
            EXIT;
        CLEAR(Remission2);
        Remission2.RESET;
        Remission2.SETCURRENTKEY("Document Type", "No.");
        Remission2.SETRANGE(Remission2."Document Type", Remission."Document Type");
        Remission2.SETRANGE(Remission2."No.", Remission."No.");
        RemissionReport.SETTABLEVIEW(Remission2);
        RemissionReport.RUN;
    end;


    procedure SetStatus(var pRemission: Record "FSN Remission Header"; NewStatus: Integer; var pError: Boolean; var pTextError: Text)
    var
        OldStatus: Integer;
        OldStatusText: Text[50];
        lCompanys: Record "FSN Company Insurer";
    begin
        //Pending,Released,Coinsurance Invoiced,Close,Voided
        OldStatus := pRemission.Status;
        OldStatusText := FORMAT(pRemission.Status);
        IF OldStatus = NewStatus THEN BEGIN
            pError := TRUE;
            pTextError := STRSUBSTNO(Text001, OldStatusText, FORMAT(pRemission.Status));
            EXIT;
        END;
        lCompanys.GET(pRemission."Company No.");

        CASE NewStatus OF
            0:
                pError := (OldStatus > NewStatus);
            1:
                pError := (OldStatus = 4);// OR (lCompanys."Send Maill");
            2, 3:
                pError := (OldStatus = 4) OR (lCompanys."Send Maill");
            4:
                pError := (OldStatus = 4);
        END;

        pRemission.Status := NewStatus;
        IF pError THEN BEGIN
            IF NewStatus > -1 THEN
                pTextError := STRSUBSTNO(Text001, OldStatusText, FORMAT(pRemission.Status))
            ELSE
                pTextError := STRSUBSTNO(Text001, OldStatusText, OldStatusText);
            EXIT;
        END;
        IF (OldStatus = 0) AND (NewStatus = 1) THEN
            pRemission."Posting Date" := TODAY;
        pRemission.ModifyTrigger;
        pRemission.MODIFY;
    end;


    procedure InsertCoinsurance(pRemission: Record "FSN Remission Header"; pCompany: Record "FSN Company Insurer")
    var
        RemissionNewLine: Record "FSN Remission Line";
        lItem: Record Item;
    begin
        IF pRemission.Status <> pRemission.Status::Pending THEN
            EXIT;
        RemissionNewLine.RESET;
        RemissionNewLine.SETRANGE(RemissionNewLine."Document Type", pRemission."Document Type");
        RemissionNewLine.SETRANGE(RemissionNewLine."Document No.", pRemission."No.");
        RemissionNewLine.SETRANGE(RemissionNewLine.Type, RemissionNewLine.Type::Coinsurance);
        RemissionNewLine.DELETEALL;

        CLEAR(RemissionNewLine);
        RemissionNewLine.INIT();
        RemissionNewLine."Document Type" := pRemission."Document Type";
        RemissionNewLine."Document No." := pRemission."No.";
        RemissionNewLine.Type := RemissionNewLine.Type::Coinsurance;
        RemissionNewLine.VALIDATE(RemissionNewLine."No.", pCompany."Item No. Coinsurance");
        RemissionNewLine.Quantity := 1;
        RemissionNewLine.VALIDATE(RemissionNewLine."Unit Price Inc. VAT", GetRemissionCoinsurance(pRemission."Document Type", pRemission."No."));
        RemissionNewLine.VALIDATE("Replication Counter");
        RemissionNewLine."Qty. Per Unit of Measure" := 1;
        IF RemissionNewLine."Unit Price Inc. VAT" > 0 THEN
            RemissionNewLine.INSERT(TRUE);
    end;


    procedure InsertDeductible(pRemission: Record "FSN Remission Header"; pCompany: Record "FSN Company Insurer")
    var
        RemissionNewLine: Record "FSN Remission Line";
    begin
        IF pRemission.Status <> pRemission.Status::Pending THEN
            EXIT;
        RemissionNewLine.RESET;
        RemissionNewLine.SETRANGE(RemissionNewLine."Document Type", pRemission."Document Type");
        RemissionNewLine.SETRANGE(RemissionNewLine."Document No.", pRemission."No.");
        RemissionNewLine.SETRANGE(RemissionNewLine.Type, RemissionNewLine.Type::Deductible);
        RemissionNewLine.DELETEALL;

        CLEAR(RemissionNewLine);
        RemissionNewLine.INIT();
        RemissionNewLine."Document Type" := pRemission."Document Type";
        RemissionNewLine."Document No." := pRemission."No.";
        RemissionNewLine.Type := RemissionNewLine.Type::Deductible;
        RemissionNewLine.VALIDATE(RemissionNewLine."No.", pCompany."Item No. Deductible");
        RemissionNewLine.Quantity := 1;
        RemissionNewLine.VALIDATE(RemissionNewLine."Unit Price Inc. VAT", GetRemissionManualDeductible(pRemission."Document Type", pRemission."No."));
        RemissionNewLine.VALIDATE("Replication Counter");
        RemissionNewLine."Qty. Per Unit of Measure" := 1;
        IF RemissionNewLine."Unit Price Inc. VAT" > 0 THEN
            RemissionNewLine.INSERT(TRUE);
    end;


    procedure InsertComission(pRemission: Record "FSN Remission Header"; pCompany: Record "FSN Company Insurer")
    var
        RemissionNewLine: Record "FSN Remission Line";
    begin
        IF pRemission.Status <> pRemission.Status::Pending THEN
            EXIT;
        RemissionNewLine.RESET;
        RemissionNewLine.SETRANGE(RemissionNewLine."Document Type", pRemission."Document Type");
        RemissionNewLine.SETRANGE(RemissionNewLine."Document No.", pRemission."No.");
        RemissionNewLine.SETRANGE(RemissionNewLine.Type, RemissionNewLine.Type::Comission);
        RemissionNewLine.DELETEALL;

        CLEAR(RemissionNewLine);
        RemissionNewLine.INIT();
        RemissionNewLine."Document Type" := pRemission."Document Type";
        RemissionNewLine."Document No." := pRemission."No.";
        RemissionNewLine.Type := RemissionNewLine.Type::Comission;
        RemissionNewLine.VALIDATE(RemissionNewLine."No.", pCompany."Item No. Comission");
        RemissionNewLine.Quantity := 1;
        RemissionNewLine.VALIDATE(RemissionNewLine."Unit Price Inc. VAT", GetRemissionComission(pRemission."Document Type", pRemission."No."));
        RemissionNewLine.VALIDATE("Replication Counter");
        RemissionNewLine."Qty. Per Unit of Measure" := 1;
        IF RemissionNewLine."Unit Price Inc. VAT" > 0 THEN
            RemissionNewLine.INSERT(TRUE);
    end;


    procedure CreateUpdRemissionWithTempTables(var pRemissionHeaderTmp: Record "FSN Remission Header" temporary; var pRemissionLineTmp: Record "FSN Remission Line" temporary; Update_Action: Text[50]; RequestID: Text[50])
    begin
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        RemissionLineTmp.RESET;
        RemissionLineTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);
        CLEAR(RemissionLineTmp);

        pRemissionHeaderTmp.RESET;
        IF pRemissionHeaderTmp.FINDSET THEN
            REPEAT
                RemissionHeaderTmp.INIT();
                RemissionHeaderTmp := pRemissionHeaderTmp;
                RemissionHeaderTmp.INSERT;
            UNTIL pRemissionHeaderTmp.NEXT = 0;

        pRemissionLineTmp.RESET;
        IF pRemissionLineTmp.FIND('-') THEN
            REPEAT
                RemissionLineTmp.INIT;
                RemissionLineTmp := pRemissionLineTmp;
                RemissionLineTmp.INSERT;
            UNTIL pRemissionLineTmp.NEXT = 0;
        GlobalAction := Update_Action;
        GlobalRequestID := RequestID;
    end;


    procedure ProcessingRemissionTempTables()
    begin
        //Remission
        IF NOT RemissionHeaderTmp.FIND('-') THEN
            ERROR(STRSUBSTNO(Text004, RemissionHeaderTmp.TABLECAPTION, RemissionHeaderTmp."No."));

        IF RemissionHeaderTmp."Company No." = '' THEN
            ERROR(STRSUBSTNO(Text011, RemissionHeaderTmp.FIELDCAPTION("Company No.")));
        IF RemissionHeaderTmp."Insured Card No." = '' THEN
            ERROR(STRSUBSTNO(Text011, RemissionHeaderTmp.FIELDCAPTION("Insured Card No.")));


        IF GlobalAction = 'Add' THEN BEGIN
            IF NOT (RemissionHeaderTmp."No." = '') THEN
                ERROR(STRSUBSTNO(Text008, RemissionHeaderTmp."No."));
            RemissionHeaderTmp."No." := NewRemission();
            IF RemissionHeader."No." = '' THEN
                ERROR(STRSUBSTNO(Text009, RemissionHeaderTmp.TABLECAPTION, RemissionHeaderTmp."No."));

            IF FORMAT(RemissionHeaderTmp) <> FORMAT(RemissionHeader) THEN BEGIN
                RemissionHeader.VALIDATE("Company No.", RemissionHeaderTmp."Company No.");
                RemissionHeader."Comission Apply" := RemissionHeaderTmp."Comission Apply";

                IF RemissionHeaderTmp."Sales Staff" <> '' THEN BEGIN
                    IF NOT Staff.GET(RemissionHeaderTmp."Sales Staff") THEN
                        ERROR(STRSUBSTNO(Text013, RemissionHeaderTmp."Sales Staff"));
                    RemissionHeader.VALIDATE("Sales Staff", RemissionHeaderTmp."Sales Staff");
                END;
                RemissionHeader.VALIDATE("Insured Card No.", RemissionHeaderTmp."Insured Card No.");
                IF RemissionHeaderTmp."Deductible Manual" > 0 THEN
                    RemissionHeader.VALIDATE("Deductible Manual", RemissionHeaderTmp."Deductible Manual");

                RemissionHeader.VALIDATE("Coinsurance No.", RemissionHeaderTmp."Coinsurance No.");

                RemissionHeader."External Document No." := RemissionHeaderTmp."External Document No.";
                RemissionHeader."Authorization No." := RemissionHeaderTmp."Authorization No.";
                RemissionHeader."Pre Authorization No." := RemissionHeaderTmp."Pre Authorization No.";
                RemissionHeader."Recipe Date" := RemissionHeaderTmp."Recipe Date";

                RemissionHeader.MODIFY(TRUE);
            END;
            RemissionLineTmp.RESET;
            IF RemissionLineTmp.FIND('-') THEN
                REPEAT
                    IF RemissionLineTmp.Type = RemissionLineTmp.Type::Item THEN BEGIN
                        RemissionLine.INIT();
                        RemissionLine."Document Type" := RemissionHeader."Document Type";
                        RemissionLine."Document No." := RemissionHeader."No.";
                        RemissionLine."Line No." := RemissionLineTmp."Line No.";
                        RemissionLine.Type := RemissionLineTmp.Type::Item;
                        Barcodes.RESET;
                        Barcodes.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");
                        Barcodes.SETRANGE(Barcodes."Item No.", RemissionLineTmp."No.");
                        Barcodes.SETRANGE(Barcodes."Unit of Measure Code", RemissionLineTmp."Unit of Measure");
                        Barcodes.FINDFIRST;
                        RemissionLine.VALIDATE(Barcode, Barcodes."Barcode No.");
                        RemissionLine.VALIDATE(Quantity, RemissionLineTmp.Quantity);
                        RemissionLine.Scanned := RemissionLineTmp.Scanned;
                        RemissionLine.Lot := RemissionLineTmp.Lot;
                        RemissionLine."Expiration Date" := RemissionLineTmp."Expiration Date";
                        RemissionLine.INSERT;
                    END;
                UNTIL RemissionLineTmp.NEXT = 0;
        END;
        IF GlobalAction = 'Update-Add' THEN BEGIN
            RemissionHeaderTmp.TESTFIELD("No.");
            RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.");
            RemissionHeader.TESTFIELD(RemissionHeader.Status, RemissionHeader.Status::Pending);

            IF FORMAT(RemissionHeader) <> FORMAT(RemissionHeaderTmp) THEN BEGIN
                IF RemissionHeaderTmp."Company No." <> RemissionHeader."Company No." THEN
                    RemissionHeader.VALIDATE("Company No.", RemissionHeaderTmp."Company No.");
                RemissionHeader."Comission Apply" := RemissionHeaderTmp."Comission Apply";

                IF RemissionHeaderTmp."Sales Staff" <> RemissionHeader."Sales Staff" THEN
                    IF RemissionHeaderTmp."Sales Staff" <> '' THEN BEGIN
                        IF NOT Staff.GET(RemissionHeaderTmp."Sales Staff") THEN
                            ERROR(STRSUBSTNO(Text013, RemissionHeaderTmp."Sales Staff"));
                        RemissionHeader.VALIDATE("Sales Staff", RemissionHeaderTmp."Sales Staff");
                    END ELSE
                        RemissionHeader."Sales Staff" := '';
                IF RemissionHeaderTmp."Insured Card No." <> RemissionHeader."Insured Card No." THEN
                    RemissionHeader.VALIDATE("Insured Card No.", RemissionHeaderTmp."Insured Card No.");
                IF RemissionHeaderTmp."Coinsurance No." <> RemissionHeader."Coinsurance No." THEN
                    RemissionHeader.VALIDATE("Coinsurance No.", RemissionHeaderTmp."Coinsurance No.");
                IF RemissionHeaderTmp."Deductible Manual" > 0 THEN
                    RemissionHeader.VALIDATE("Deductible Manual", RemissionHeaderTmp."Deductible Manual")
                ELSE
                    RemissionHeader."Deductible Manual" := 0;

                RemissionHeader."External Document No." := RemissionHeaderTmp."External Document No.";
                RemissionHeader."Authorization No." := RemissionHeaderTmp."Authorization No.";
                RemissionHeader."Pre Authorization No." := RemissionHeaderTmp."Pre Authorization No.";
                RemissionHeader."Recipe Date" := RemissionHeaderTmp."Recipe Date";
                RemissionHeader.MODIFY(TRUE);
            END;
            RemissionLine.RESET;
            RemissionLine.SETRANGE(RemissionLine."Document Type", RemissionHeader."Document Type");
            RemissionLine.SETRANGE(RemissionLine."Document No.", RemissionHeader."No.");
            IF RemissionLine.FINDFIRST THEN
                REPEAT
                    IF NOT RemissionLineTmp.GET(RemissionLine."Document Type", RemissionLine."Document No.", RemissionLine."Line No.") THEN
                        RemissionLine.DELETE(TRUE);
                UNTIL RemissionLine.NEXT = 0;
            Barcodes.RESET;
            Barcodes.SETCURRENTKEY("Item No.", "Variant Code", "Unit of Measure Code");

            RemissionLineTmp.RESET;
            RemissionLineTmp.SETRANGE(RemissionLineTmp."Document Type", RemissionHeader."Document Type");
            RemissionLineTmp.SETRANGE(RemissionLineTmp."Document No.", RemissionHeader."No.");
            IF RemissionLineTmp.FINDFIRST THEN
                REPEAT
                    Barcodes.SETRANGE(Barcodes."Item No.", RemissionLineTmp."No.");
                    Barcodes.SETRANGE(Barcodes."Unit of Measure Code", RemissionLineTmp."Unit of Measure");
                    Barcodes.FINDFIRST;

                    IF RemissionLine.GET(RemissionLineTmp."Document Type", RemissionLineTmp."Document No.", RemissionLineTmp."Line No.") THEN BEGIN
                        IF FORMAT(RemissionLine) <> FORMAT(RemissionLineTmp) THEN BEGIN
                            IF (RemissionLineTmp."No." <> RemissionLine."No.") OR (RemissionLine."Unit of Measure" <> RemissionLineTmp."Unit of Measure") THEN BEGIN
                                RemissionLine.Type := RemissionLine.Type::Item;
                                RemissionLine.VALIDATE(RemissionLine.Barcode, Barcodes."Barcode No.");
                                RemissionLine.VALIDATE("Unit of Measure", RemissionLineTmp."Unit of Measure");
                            END;
                            RemissionLine.VALIDATE(Quantity, RemissionLineTmp.Quantity);
                            RemissionLine.Scanned := RemissionLineTmp.Scanned;
                            RemissionLine.lot := RemissionLineTmp.Lot;
                            RemissionLine."Expiration Date" := RemissionLineTmp."Expiration Date";
                            RemissionLine.MODIFY(TRUE);
                        END;
                    END ELSE BEGIN
                        RemissionLine.INIT();
                        RemissionLine."Document Type" := RemissionLineTmp."Document Type";
                        RemissionLine."Document No." := RemissionLineTmp."Document No.";
                        RemissionLine."Line No." := RemissionLineTmp."Line No.";
                        RemissionLine.Type := RemissionLineTmp.Type;
                        RemissionLine.VALIDATE(Barcode, Barcodes."Barcode No.");
                        RemissionLine.Recipe := RemissionLineTmp.Recipe;
                        RemissionLine.VALIDATE("Unit of Measure", RemissionLineTmp."Unit of Measure");
                        RemissionLine.VALIDATE(Quantity, RemissionLineTmp.Quantity);
                        RemissionLine."Store No." := RemissionHeader."Store No.";
                        RemissionLine.Scanned := RemissionLineTmp.Scanned;
                        RemissionLine.Lot := RemissionLineTmp.Lot;
                        RemissionLine."Expiration Date" := RemissionLineTmp."Expiration Date";
                        RemissionLine.INSERT(TRUE);
                    END;
                UNTIL RemissionLineTmp.NEXT = 0;
        END;
        REMISSION := RemissionHeader."No.";
    end;


    procedure CreateUpdInsuredWithTempTables(var pInsuredTmp: Record "FSN Insured Links" temporary; Update_Action: Text[50]; RequestID: Text[50])
    begin
        InsuredLinkTmp.RESET;
        InsuredLinkTmp.DELETEALL;

        pInsuredTmp.RESET;
        IF pInsuredTmp.FIND('-') THEN
            REPEAT
                InsuredLinkTmp.INIT();
                InsuredLinkTmp := pInsuredTmp;
                InsuredLinkTmp.INSERT;
            UNTIL pInsuredTmp.NEXT = 0;

        GlobalAction := Update_Action;
        GlobalRequestID := RequestID;
    end;


    procedure ProcessingInsuredTempTables()
    begin
        InsuredLinkTmp.RESET;
        IF NOT InsuredLinkTmp.FIND('-') THEN
            ERROR(STRSUBSTNO(Text004, InsuredLinkTmp.TABLECAPTION, InsuredLinkTmp.Card));

        CASE GlobalAction OF
            'Add':
                BEGIN
                    IF InsuredLinkTmp.FIND('-') THEN
                        REPEAT
                            IF InsuredLink.GET(InsuredLinkTmp."Company No.", InsuredLinkTmp.Card) THEN
                                ERROR(STRSUBSTNO(Text010, InsuredLink.TABLECAPTION, InsuredLinkTmp."Company No.", InsuredLinkTmp.Card, '', ''));
                            InsuredLink.INIT();
                            InsuredLink.VALIDATE(InsuredLink."Company No.", InsuredLinkTmp."Company No.");
                            InsuredLink.VALIDATE(InsuredLink.Card, InsuredLinkTmp.Card);
                            InsuredLink.VALIDATE("Customer No.", InsuredLinkTmp."Customer No.");
                            InsuredLink.Name := UPPERCASE(InsuredLinkTmp.Name);
                            InsuredLink.Relation := InsuredLinkTmp.Relation;
                            IF InsuredLink.Relation = InsuredLink.Relation::Parent THEN
                                InsuredLink."Parent Card" := InsuredLink.Card
                            ELSE
                                InsuredLink.VALIDATE("Parent Card", InsuredLinkTmp."Parent Card");
                            InsuredLink.Email := InsuredLinkTmp.Email;
                            InsuredLink.Inactive := InsuredLinkTmp.Inactive;
                            InsuredLink.INSERT(TRUE);
                        UNTIL InsuredLinkTmp.NEXT = 0;
                END;
            'Update-Add':
                BEGIN
                    IF InsuredLinkTmp.FIND('-') THEN
                        REPEAT
                            InsuredLink.GET(InsuredLinkTmp."Company No.", InsuredLinkTmp.Card);
                            IF FORMAT(InsuredLinkTmp) <> FORMAT(InsuredLink) THEN BEGIN
                                IF InsuredLinkTmp."Customer No." <> InsuredLink."Customer No." THEN
                                    InsuredLink.VALIDATE("Customer No.", InsuredLinkTmp."Customer No.");
                                InsuredLink.Name := InsuredLinkTmp.Name;
                                InsuredLink.Relation := InsuredLinkTmp.Relation;
                                IF InsuredLink.Relation = InsuredLink.Relation::Parent THEN
                                    InsuredLink."Parent Card" := InsuredLink.Card
                                ELSE
                                    InsuredLink.VALIDATE("Parent Card", InsuredLinkTmp."Parent Card");
                                InsuredLink.Email := InsuredLinkTmp.Email;
                                InsuredLink.Inactive := InsuredLinkTmp.Inactive;
                                InsuredLink.MODIFY(TRUE);
                            END;
                        UNTIL InsuredLinkTmp.NEXT = 0;
                END;
        END;
    end;


    procedure SetRemissionHeaderTempTables(var pRemission: Record "FSN Remission Header" temporary; RequestID: Text[50])
    begin
        RemissionHeaderTmp.RESET;
        RemissionHeaderTmp.DELETEALL;
        CLEAR(RemissionHeaderTmp);

        IF pRemission.FIND('-') THEN
            REPEAT
                RemissionHeaderTmp.INIT();
                RemissionHeaderTmp := pRemission;
                RemissionHeaderTmp.INSERT;
            UNTIL pRemission.NEXT = 0;
        GlobalRequestID := RequestID;
    end;


    procedure ProcessingPostRemission()
    var
        pError: Boolean;
        pErrorText: Text;
    begin
        IF NOT RemissionHeaderTmp.FIND('-') THEN
            ERROR(STRSUBSTNO(Text004, RemissionHeaderTmp.TABLECAPTION, RemissionHeaderTmp."No."));

        RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.");
        PostRemission(RemissionHeader, pError, pErrorText);
        IF pError THEN
            ERROR(pErrorText);

        REMISSION := RemissionHeader."No.";
    end;


    procedure ProcessingReturnStatus()
    var
        NewStatus: Integer;
        pError: Boolean;
        pErrorText: Text;
    begin
        IF NOT RemissionHeaderTmp.FIND('-') THEN
            ERROR(STRSUBSTNO(Text004, RemissionHeaderTmp.TABLECAPTION, RemissionHeaderTmp."No."));

        RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.");
        IF RemissionHeader.Status = RemissionHeader.Status::Pending THEN
            ERROR(Text012);

        NewStatus := RemissionHeader.Status - 1;
        SetStatus(RemissionHeader, NewStatus, pError, pErrorText);
        IF pError THEN
            ERROR(pErrorText);

        REMISSION := RemissionHeader."No.";
    end;


    procedure ProcessingVoidRemission()
    var
        pError: Boolean;
        pErrorText: Text;
    begin
        IF NOT RemissionHeaderTmp.FIND('-') THEN
            ERROR(STRSUBSTNO(Text004, RemissionHeaderTmp.TABLECAPTION, RemissionHeaderTmp."No."));
        RemissionHeader.GET(RemissionHeaderTmp."Document Type", RemissionHeaderTmp."No.");
        SetStatus(RemissionHeader, 4, pError, pErrorText);

        IF pError THEN
            ERROR(pErrorText);

        REMISSION := RemissionHeader."No.";
    end;

    procedure GetCurrRemission(): Code[20]
    begin
        EXIT(REMISSION);
    end;

    procedure ValidateEmail(pEmail: Text[80])
    var
        TmpRecipients: Text[80];
    begin
        IF pEmail = '' THEN
            ERROR(Text001, pEmail);

        TmpRecipients := pEmail;
        IF NOT (STRPOS(TmpRecipients, ';') > 1) THEN
            ValidateEmailDetails(pEmail)
        ELSE BEGIN
            IF COPYSTR(TmpRecipients, STRLEN(TmpRecipients), 1) = ';' THEN
                ERROR(Text002);
            TmpRecipients += ';';
        END;

        WHILE STRPOS(TmpRecipients, ';') > 1 DO BEGIN
            ValidateEmailDetails(COPYSTR(TmpRecipients, 1, STRPOS(TmpRecipients, ';') - 1));
            TmpRecipients := COPYSTR(TmpRecipients, STRPOS(TmpRecipients, ';') + 1);
        END;
    end;

    procedure ValidateEmailDetails(pEmail: Text[80])
    var
        i: Integer;
        NoOfAtSigns: Integer;
        RegEx: DotNet Regex;
    begin

        IF pEmail = '' THEN
            ERROR(Text001, pEmail);

        IF (pEmail[1] = '@') OR (pEmail[STRLEN(pEmail)] = '@') THEN
            ERROR(Text001, pEmail);

        FOR i := 1 TO STRLEN(pEmail) DO BEGIN
            IF pEmail[i] = '@' THEN
                NoOfAtSigns := NoOfAtSigns + 1
            ELSE
                IF pEmail[i] = ' ' THEN
                    ERROR(Text001, pEmail);
        END;

        IF NoOfAtSigns <> 1 THEN
            ERROR(Text001, pEmail);

        IF NOT RegEx.IsMatch(pEmail, '^[\w._%-]+@[\w.-]+\.[a-zA-Z]{2,4}$') THEN
            ERROR(Text001, pEmail);

    end;

    local procedure SendRemissionToMH(var Remission: Record "FSN Remission Header")
    var
        remissionTransaction, remissionItem : JsonObject;
        remissionItemList: JsonArray;
        remissionLine: Record "FSN Remission Line";
        insurer: Record "FSN Company Insurer";
        fsnUtility: Codeunit "FSN Utility";
        req, res, ID, msgResult : Text;
        menuLine: Record "LSC POS Menu Line";
        processed: Boolean;
    begin
        //*datos de la remision
        remissionTransaction.Add('No', Remission."No.");
        remissionTransaction.Add('CompanyCode', getCompanyCode(Remission."Company No."));
        remissionTransaction.Add('CreateDate', Remission."Create Date");
        remissionTransaction.Add('CreateTime', Format(Time()));
        remissionTransaction.Add('StoreNo', Remission."Store No.");
        remissionTransaction.Add('TerminalNo', Remission."POS Terminal No.");
        remission.CalcFields("Amount", "Amount Including VAT");
        remissionTransaction.Add('netAmount', Remission."Amount");
        remissionTransaction.Add('vatAmount', Remission."Amount Including VAT");

        //*items de la remision
        remissionLine.SetCurrentKey("Document Type", "Document No.", "Line No.");
        remissionLine.SETRANGE("Document Type", Remission."Document Type");
        remissionLine.SETRANGE("Document No.", Remission."No.");
        if not remissionLine.FINDSET then
            ERROR(Text004, RemissionLine.TABLECAPTION, RemissionLine."No.");

        repeat
            Clear(remissionItem);
            remissionItem.Add('No', remissionLine."No.");
            remissionItem.Add('UOM', remissionLine."Unit of Measure");
            remissionItem.Add('Quantity', remissionLine."Quantity");
            remissionItem.Add('VatAmount', remissionLine."Amount Including VAT");
            remissionItem.Add('unitPrice', remissionLine."Unit Price Inc. VAT");
            remissionItem.Add('discountAmount', remissionLine."Discount Amount");
            remissionItem.Add('sellerCode', remission."Sales Staff");
            remissionItemList.Add(remissionItem);
        until remissionLine.NEXT = 0;

        remissionTransaction.Add('Items', remissionItemList);
        remissionTransaction.WriteTo(req);
        ID := 'GENERATE_REMISSION';
        //TODO(): Evaluar si la empresa tiene el valor de "usar Remision"
        if insurer.Get(Remission."Company No.") then
            if insurer."Usar Remision" then
                fsnUtility.InvokeGlobalChannel(req, res, ID, menuLine, processed, msgResult);
    end;

    local procedure getCompanyCode(CompanyNo: Code[20]): Text
    var
        lCompany: Record "FSN Company Insurer";
    begin
        lCompany.Get(CompanyNo);
        exit(lCompany."Customer No.");
    end;

    local procedure getDatafromRemission(var XMLRequest: Text; var XMLResponse: Text; var Processed: Boolean; var MsgResult: Text)
    var
        ERROR_MESSAGE: Label 'Remission with serial number %1 not found';
        remissionHeader: Record "FSN Remission Header";
        json: JsonObject;
    begin
        remissionHeader.SetRange("No.", XMLRequest);
        if not remissionHeader.FindFirst() then begin
            MsgResult := StrSubstNo(ERROR_MESSAGE, XMLRequest);
            Processed := false;
        end;

        json.Add('authNumber', remissionHeader."Auth Number");
        json.Add('IssuedDate', remissionHeader."Issued Date");

        json.WriteTo(XMLResponse);
        Processed := true;
    end;

    local procedure SaveDTEInvoice(var XMLRequest: Text; var XMLResponse: Text; var Processed: Boolean; var MsgResult: Text)
    var
        ERROR_MESSAGE: Label 'Remission with serial number %1 not found';
        remissionHeader: Record "FSN Remission Header";
        json: JsonObject;
        token: JsonToken;
        receipt: Text;
    begin
        json.ReadFrom(XMLRequest);
        if json.SelectToken('transNo', token) then
            receipt := token.AsValue().AsText();

        remissionHeader.SetCurrentKey("Document Type", "No.");
        remissionHeader.SetRange("No.", receipt);
        if not remissionHeader.FindFirst() then begin
            MsgResult := StrSubstNo(ERROR_MESSAGE, receipt);
            Processed := false;
        end;

        if json.SelectToken('authNumber', token) then
            remissionHeader."Auth Number" := token.AsValue().AsText();

        if json.SelectToken('generationDate', token) then
            remissionHeader."Issued Date" := token.AsValue().AsDate();

        remissionHeader.Modify(false);
        Processed := true;
    end;

    local procedure GetDTEParams(remision: Record "FSN Remission Header"): Boolean
    var
        parameter: Record "FSN Parameter";
        posSession: Codeunit "LSC POS Session";
        terminal: Text;
    begin
        if remision."POS Terminal No." <> '' then
            terminal := remision."POS Terminal No."
        else
            terminal := posSession.TerminalNo();

        parameter.SetCurrentKey(Grupo, Codigo);
        parameter.SetRange(grupo, 'DTE_INVOICE');
        parameter.SetRange(Codigo, terminal);
        parameter.SetRange(Valor, 'WS');
        if not parameter.FindFirst() then
            exit(false);

        exit(parameter.Activo);
    end;

    local procedure validateAuthNo(AuthorizationNo: Text[30]; company: Enum "Validate Auth No Company"; var pError: Boolean; var pTextError: Text)
    var
        client: HttpClient;
        headers: HttpHeaders;
        request: HttpRequestMessage;
        response: HttpResponseMessage;
        content: HttpContent;
        token, uri : Text;
        parameter: Record "FSN Parameter";
    begin
        token := GetToken();
        if token = '' then begin
            pError := true;
            pTextError := 'No se pudo obtener el token';
            exit;
        end;

        if not parameter.Get('REMISSION', 'SERVER') then begin
            pError := true;
            pTextError := 'No se pudo obtener el parametro de la API';
            exit;
        end;

        uri := parameter."Web Uri" + StrSubstNo('/Get%1Document?%1AuthNum=%2', company, AuthorizationNo);

        request.GetHeaders(headers);
        headers.Clear();
        headers.Add('Authorization', 'Bearer ' + token);

        request.Method := 'GET';
        request.SetRequestUri(uri);
        client.Send(request, response);
        content := response.Content;
        if response.HttpStatusCode <> 200 then begin
            content.ReadAs(pTextError);
            pError := true;
            exit;
        end;
    end;

    local procedure GetToken(): Text
    var
        client: HttpClient;
        request: HttpRequestMessage;
        response: HttpResponseMessage;
        content: HttpContent;
        headers: HttpHeaders;
        credential, uri, res : Text;
        parameter: Record "FSN Parameter";
        json: JsonObject;
        token: JsonToken;
    begin
        if not parameter.Get('REMISSION', 'SERVER') then
            exit('');

        credential := StrSubstNo('{ "username": "%1", "passkey": "%2" }', parameter."Value Text 1", parameter."Value Text 2");

        uri := parameter."Web Uri" + '/GetToken';
        content.WriteFrom(credential);
        content.GetHeaders(headers);
        headers.Clear();
        headers.Add('Content-Type', 'application/json');
        request.Content := content;
        request.Method := 'POST';
        request.SetRequestUri(uri);

        client.Send(request, response);

        content := response.Content;
        content.ReadAs(res);

        json.ReadFrom(res);
        if json.SelectToken('Token', token) then
            exit(token.AsValue().AsText())
        else
            exit('');
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"FSN Utility", 'OnInvokeGlobalChannelEvent', '', false, false)]
    local procedure OnInvokeGlobalChannelEvent(var XMLRequest: Text; var XMLResponse: Text; var RequestID: Text[50]; var POSMenuLine: Record "LSC POS Menu Line"; var Processed: Boolean; var MsgResult: Text);
    begin
        if RequestID = 'DTE_REMISSION_DATA' then begin
            getDatafromRemission(XMLRequest, XMLResponse, Processed, MsgResult);
            exit;
        end;

        if RequestID = 'SAVE_DTE_INVOICE' then begin
            SaveDTEInvoice(XMLRequest, XMLResponse, Processed, MsgResult);
            exit;
        end;
    end;
}

