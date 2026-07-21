page 50063 "FSN POS Card Prov. VS Client" //60017 -50104
{
    // WVILLALTA 9.20                      -  Check Card payment

    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = ListPart;
    SourceTable = "FSN POS Card Prov. VS Customer";

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Status; Status)
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = TRUE;
                }
                field("Trans. Date"; "Trans. Date")
                {
                    Editable = false;
                }
                field("Trans. Time"; "Trans. Time")
                {
                    Editable = false;
                }
                field("Store No."; "Store No.")
                {
                    Editable = false;
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Editable = false;
                }
                field("Receipt No."; "Receipt No.")
                {
                    Editable = false;
                }
                field("Customer No."; "Customer No.")
                {
                    Editable = false;
                }
                field("Customer Name"; "Customer Name")
                {
                    Editable = false;
                }
                field(Amount; Amount)
                {
                    Editable = false;
                }
                field("Amount Pending"; "Amount Pending")
                {
                }
                field(NCF; NCF)
                {
                    Editable = false;
                }
                field("Provider Entry No."; "Provider Entry No.")
                {
                    Caption = 'Provider Entry No.';

                    trigger OnLookup(var Text: Text): Boolean
                    var
                        PAGECardProviders: Page "FSN Lookup Cards Providers";
                        TABLECardProviders: Record "FSN POS Card Providers";
                        VoucherRef: Record "FSN POS Card Providers";
                    begin
                        IF Close THEN
                            EXIT;

                        PAGECardProviders.LOOKUPMODE := TRUE;
                        TABLECardProviders.SETCURRENTKEY(Close);
                        TABLECardProviders.SETRANGE(TABLECardProviders.Close, FALSE);
                        PAGECardProviders.LookUPOnly;
                        IF PAGECardProviders.RUNMODAL = ACTION::LookupOK THEN BEGIN
                            //EXIT(TRUE);
                        END;// ELSE
                        //  EXIT(FALSE);
                        PAGECardProviders.GetLastRec(VoucherRef);
                        COMMIT;
                        IF NOT CONFIRM(STRSUBSTNO(Text001, VoucherRef."Auth. Code", VoucherRef."Reference No.", FORMAT(VoucherRef."Amount Transaction"))) THEN
                            EXIT;

                        POSCardMGT.CheckCreateLink(Rec, VoucherRef);
                        COMMIT;
                        CurrPage.UPDATE(FALSE);
                    end;

                    trigger OnValidate()
                    begin
                        ERROR(Text000);
                    end;
                }
                field("Transaction No."; "Transaction No.")
                {
                    Editable = false;
                }
                field("Amount Invoice"; "Amount Invoice")
                {
                    Editable = false;
                }
                field("Auth. Code"; "Auth. Code")
                {
                }
                field(BIN; BIN)
                {
                }
                field("Terminal ID"; "Terminal ID")
                {
                }
                field("Reference No."; "Reference No.")
                {
                }
                field("Staff ID"; "Staff ID")
                {
                    Editable = false;
                }
                field("Process Message"; "Process Message")
                {
                    Editable = false;
                }
                field("Is Return"; "Is Return")
                {
                    Editable = false;
                }
                field("Consignment Amount"; "Consignment Amount")
                {
                    Editable = false;
                }
                field("Consigment No."; "Consigment No.")
                {

                    trigger OnValidate()
                    begin
                        MODIFY;
                        COMMIT;
                        Rec.GET("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
                        CurrPage.UPDATE(FALSE);
                    end;
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Consigment Apply")
            {
                Caption = 'Consigment Apply';

                trigger OnAction()
                var
                    Voucher_l: Record "FSN POS Card Providers";
                begin
                    TESTFIELD("Is Return", FALSE);
                    TESTFIELD("Consigment No.");
                    TESTFIELD(Status, Status::Partial);

                    VALIDATE(Status, Status::Complete);
                    /*
                    Voucher_l.RESET;
                    Voucher_l.SETRANGE(Voucher_l."Entry No.","Provider Entry No.");
                    Voucher_l.SETRANGE(Voucher_l."Auth. Code","Auth. Code");
                    Voucher_l.FINDFIRST;
                    */
                    COMMIT;
                    IF NOT CONFIRM(STRSUBSTNO(Text002, "Consigment No.", FORMAT("Amount Pending"))) THEN
                        EXIT;

                    VALIDATE(Status, Status::Complete);
                    "Consignment Amount" := "Amount Pending";
                    "Amount Pending" := 0;
                    MODIFY;

                    GET("Store No.", "POS Terminal No.", "Transaction No.", "Line No.");
                    CurrPage.UPDATE(FALSE);

                end;
            }
            action("Apply Like Cash Tender")
            {
                Caption = 'Apply Like Cash Tender';

                trigger OnAction()
                begin
                    TESTFIELD(Status, Status::Open);
                    TESTFIELD("Is Return", FALSE);
                    COMMIT;
                    IF NOT CONFIRM(STRSUBSTNO(Text003, "Customer No." + '-' + "Customer Name", FORMAT(Amount), "Store No.")) THEN
                        EXIT;

                    "Process Message" := STRSUBSTNO(Text004, USERID);
                    "Consigment No." := '';
                    VALIDATE(Status, Status::CashApply);
                    MODIFY;
                end;
            }
            action("Seach Card Mask")
            {
                Caption = 'Seach Card Mask';

                trigger OnAction()
                var
                    PAGECardProviders: Page "FSN Lookup Cards Providers";
                    TABLECardProviders: Record "FSN POS Card Providers";
                    VoucherRef: Record "FSN POS Card Providers";
                    TransRef: Record "FSN POS Card Prov. VS Customer";
                    TableTmp: Record "FSN Global Table Temporary" temporary;//"50007"
                    StrFilter: Text;
                    Ok_: Boolean;
                    Counter1: Integer;
                begin
                    IF NOT (Status IN [Status::Open, Status::Partial]) THEN
                        EXIT;

                    TableTmp.RESET;
                    TableTmp.DELETEALL;
                    Ok_ := FALSE;
                    CLEAR(Counter1);

                    TransRef.RESET;
                    TransRef.SETCURRENTKEY("Store No.", "Customer No.", "Trans. Date", Status, Amount);
                    TransRef.SETRANGE(TransRef."Customer No.", "Customer No.");
                    TransRef.SETRANGE(TransRef.Status, TransRef.Status::Complete);
                    IF TransRef.FIND('-') THEN BEGIN
                        Ok_ := TRUE;
                        REPEAT
                            //"Code10_1","Code10_2","Code20_1","Code20_2","Int_1","Counter1"
                            VoucherRef.RESET;
                            VoucherRef.SETCURRENTKEY("Entry No.");
                            VoucherRef.SETRANGE(VoucherRef."Entry No.", TransRef."Provider Entry No.");
                            VoucherRef.SETRANGE(VoucherRef."Auth. Code", TransRef."Auth. Code");
                            IF VoucherRef.FIND('-') THEN
                                IF NOT TableTmp.GET('', '', '', VoucherRef."Card Mask", 0, 0) THEN BEGIN
                                    TableTmp.Code20_2 := VoucherRef."Card Mask";
                                    TableTmp.Int_2 := VoucherRef."Entry No.";
                                    TableTmp.INSERT;
                                    Counter1 += 1;
                                END;
                        UNTIL (TransRef.NEXT = 0) OR (Counter1 >= 10);
                    END;

                    IF Ok_ THEN BEGIN
                        CLEAR(StrFilter);
                        IF TableTmp.FIND('-') THEN
                            REPEAT
                                StrFilter += FORMAT(TableTmp.Int_2) + '|';
                            UNTIL TableTmp.NEXT = 0;

                        StrFilter := COPYSTR(StrFilter, 1, STRLEN(StrFilter) - 1);
                        VoucherRef.RESET;
                        VoucherRef.SETCURRENTKEY("Entry No.");
                        VoucherRef.SETFILTER(VoucherRef."Entry No.", StrFilter);
                        PAGECardProviders.SETTABLEVIEW(VoucherRef);
                        PAGECardProviders.RUN;
                    END ELSE
                        MESSAGE(STRSUBSTNO(Text005, "Customer No."));
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        CLEAR(Document2);
    end;

    trigger OnInit()
    begin
        GlobalsDate := 0D;
        GlobalPendingOnly := FALSE;
    end;

    trigger OnOpenPage()
    begin
        SetWorkDate(GlobalsDate, GlobalPendingOnly);
    end;

    var
        GlobalsDate: Date;
        GlobalPendingOnly: Boolean;
        Text000: Label 'Cant be set Entry No. directly , must be select from lookup';
        Text001: Label 'Comfirm selection \Aut.Code %1  \Referece %2 \Amount  $%3';
        POSCardMGT: Codeunit "FSN POS Card Providers Mgt.";
        Document2: Text[20];
        Text002: Label 'Apply Consigment %1?. Amount a calcular %2';
        Text003: Label 'Apply Cross Cash?\Custom:%1\Amount %2\Store %3';
        Text004: Label 'Apply Cash by %1';
        Text005: Label 'History not exists for Customer No.= %1';


    procedure SetWorkDate(pDate: Date; pPendingOnly: Boolean)
    begin
        GlobalsDate := pDate;
        GlobalPendingOnly := pPendingOnly;

        SETRANGE("Trans. Date", GlobalsDate);
        IF GlobalPendingOnly THEN
            SETRANGE(Close, FALSE)
        ELSE
            SETRANGE(Close, TRUE);
        CurrPage.UPDATE;
    end;
}

