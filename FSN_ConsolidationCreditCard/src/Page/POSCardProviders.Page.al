page 50061 "FSN POS Card Providers" //60016 - 50102
{
    // WVILLALTA 9.20                      -  Check Card payment

    Editable = true;
    InsertAllowed = false;
    PageType = ListPart;
    ShowFilter = true;
    SourceTable = "FSN POS Card Providers";
    Caption = 'POS Card Providers';

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field(Status; Rec.Status)
                {
                    Editable = false;
                    Style = Strong;
                    StyleExpr = TRUE;
                }
                field("Date Key"; Rec."Date Key")
                {
                    Enabled = false;
                }
                field("Trans. Time Text"; Rec."Trans. Time Text")
                {
                }
                field("Store Apply"; "Store Apply")
                {
                }
                field("Terminal ID"; Rec."Terminal ID")
                {
                    Enabled = false;
                }
                field("Auth. Code"; Rec."Auth. Code")
                {
                    Enabled = false;
                }
                field("Reference No."; Rec."Reference No.")
                {
                    Enabled = false;
                }
                field("Card Mask"; Rec."Card Mask")
                {
                }
                field("Amount Transaction"; Rec."Amount Transaction")
                {
                    Enabled = false;
                }
                field("Store In Setup"; Rec."Store In Setup")
                {
                    Editable = false;
                }
                field("Entry No."; Rec."Entry No.")
                {
                    Editable = false;
                }
                field("Audit Number"; Rec."Audit Number")
                {
                }
                field("Retailer ID"; Rec."Retailer ID")
                {
                    Enabled = false;
                }
                field("Amount Commission"; Rec."Amount Commission")
                {
                }
                field("Provider Name"; Rec."Provider Name")
                {
                }
                field("Trans. Type"; Rec."Trans. Type")
                {
                }
                field("Extra Data 1"; Rec."Extra Data 1")
                {
                }
                field("Parent Entry No."; Rec."Parent Entry No.")
                {
                    Caption = 'Parent Entry No.';
                    Editable = false;
                }
                field("Parent Amount"; Rec."Parent Amount")
                {
                    Caption = 'Parent Amount';
                }
                field("User No."; Rec."User No.")
                {
                }
                field("Count Records"; Rec."Count Records")
                {
                    Editable = false;
                }
                field("Is Reverse"; Rec."Is Reverse")
                {
                }
                field("Amount In Payments"; Rec."Amount In Payments")
                {
                    Editable = false;
                }
                field("Close Diff. Amount"; Rec."Close Diff. Amount")
                {
                    Editable = false;
                }
                field("Close Diff. Refund"; Rec."Close Diff. Refund")
                {
                    Editable = false;
                }
                field("Close Diff. Like Cash"; Rec."Close Diff. Like Cash")
                {
                }
                field("Last Customer No."; Rec."Last Customer No.")
                {
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            group(Reverse)
            {
                Caption = 'Reverse';
                action("Cancel by Refund")
                {
                    Caption = 'Cancel by Refund';

                    trigger OnAction()
                    var
                        lStore: Code[10];
                        lSelect: Integer;
                        lText000: Label 'Cancel Partial,Cancel Complete';
                        lSums: Decimal;
                        lInt: Integer;
                    begin
                        IF "Date Key" = 0D THEN
                            EXIT;
                        TESTFIELD("Store Apply");
                        lStore := "Store Apply";
                        //ERROR('Mantenimiento');
                        lSelect := 0;

                        IF "Amount In Payments" > 0 THEN BEGIN
                            lSelect := STRMENU(lText000);
                            IF lSelect = 0 THEN
                                EXIT;

                            IF lSelect = 1 THEN BEGIN
                                IF Status = Status::Inherit THEN
                                    ERROR(STRSUBSTNO(Text015, FORMAT(Status)));

                                VALIDATE(Status, Status::Complete);
                                "User No." := COPYSTR(COPYSTR(USERID, 1, 20) + '-' + Text014, 1, MAXSTRLEN("User No."));
                                "Close Diff. Refund" := CardProvMgt.VoucherCalcTotalAmt(Rec) - CardProvMgt.VoucherCalcUsing(Rec);
                                MODIFY;
                                EXIT;
                            END;
                        END;

                        IF lSelect = 0 THEN
                            IF NOT CONFIRM(STRSUBSTNO(Text010, FORMAT("Date Key"), "Auth. Code", FORMAT("Amount Transaction"))) THEN
                                EXIT;

                        CardProvMgt.ApplyCancelVoucher(Rec);
                        Rec.GET("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
                        VALIDATE(Status, Status::Cancelled);
                        "User No." := COPYSTR(COPYSTR(USERID, 1, 20) + Text011, 1, MAXSTRLEN("User No."));
                        "Store Apply" := lStore;
                        MODIFY;
                        GET("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
                        COMMIT;
                        CurrPage.UPDATE(FALSE);
                    end;
                }
                action("Cancel Links")
                {
                    Caption = 'Cancel Links (Re Open)';

                    trigger OnAction()
                    begin
                        IF "Date Key" = 0D THEN
                            EXIT;

                        //IF "Amount In Payments" = 0 THEN BEGIN
                        IF CONFIRM(STRSUBSTNO(Text001, FORMAT("Date Key"), "Auth. Code", FORMAT("Amount Transaction"))) THEN BEGIN
                            CardProvMgt.ApplyCancelVoucher(Rec);
                            EXIT;
                        END;
                        //END;
                        //MESSAGE(Text002);
                        CurrPage.UPDATE;
                    end;
                }
                action("Apply Like Apply")
                {
                    Caption = 'Apply Like Apply';

                    trigger OnAction()
                    var
                        lStore: Code[10];
                        lSelect: Integer;
                        lSums: Decimal;
                        lInt: Integer;
                        lText000: Label 'Cash Apply Partial,Cash Apply Complete';
                    begin
                        IF "Date Key" = 0D THEN
                            EXIT;
                        TESTFIELD(Close, FALSE);
                        TESTFIELD("Store Apply");
                        lStore := "Store Apply";

                        lSelect := 0;
                        IF "Amount In Payments" > 0 THEN BEGIN
                            lSelect := STRMENU(lText000);
                            IF lSelect = 0 THEN
                                EXIT;

                            IF lSelect = 1 THEN BEGIN
                                IF Status = Status::Inherit THEN
                                    ERROR(STRSUBSTNO(Text016, FORMAT(Status)));

                                VALIDATE(Status, Status::Complete);
                                "User No." := COPYSTR(COPYSTR(USERID, 1, 20) + '-' + Text017, 1, MAXSTRLEN("User No."));
                                "Close Diff. Like Cash" := CardProvMgt.VoucherCalcTotalAmt(Rec) - CardProvMgt.VoucherCalcUsing(Rec);
                                MODIFY;
                                EXIT;
                            END;
                        END;

                        IF lSelect = 0 THEN
                            IF NOT CONFIRM(STRSUBSTNO(Text018, FORMAT("Date Key"), "Auth. Code", FORMAT("Amount Transaction"))) THEN
                                EXIT;

                        CardProvMgt.ApplyCancelVoucher(Rec);
                        Rec.GET("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
                        VALIDATE(Status, Status::CashApply);
                        "User No." := COPYSTR(COPYSTR(USERID, 1, 20) + Text019, 1, MAXSTRLEN("User No."));
                        MODIFY;
                        GET("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");
                        COMMIT;
                        CurrPage.UPDATE(FALSE);
                    end;
                }
                action("Apply Credit Customer")
                {

                    trigger OnAction()
                    begin
                        IF "Date Key" = 0D THEN
                            EXIT;
                        TESTFIELD(Status, Status::Open);
                        IF Close THEN
                            EXIT;

                        TESTFIELD("Parent Entry No.", 0);
                        TESTFIELD("Amount In Payments", 0);
                        IF NOT CONFIRM(STRSUBSTNO(Text020, FORMAT("Date Key"), "Auth. Code", FORMAT("Amount Transaction"))) THEN
                            EXIT;

                        VALIDATE(Status, Status::ApplyCreditCustom);
                        "User No." := COPYSTR(Text021 + ' ' + USERID, 1, MAXSTRLEN("User No."));
                        MODIFY;
                    end;
                }
            }
            action(Inherit)
            {
                Caption = 'Inherit';
                Image = CreateMovement;

                trigger OnAction()
                var
                    PAGECardProviders: Page "FSN Lookup Cards Providers";
                    TABLECardProviders: Record "FSN POS Card Providers";
                    VoucherRef: Record "FSN POS Card Providers";
                begin
                    IF "Date Key" = 0D THEN
                        EXIT;

                    TESTFIELD(Status, Status::Open);
                    IF Close THEN
                        EXIT;

                    IF "Parent Entry No." > 0 THEN
                        IF "Parent Entry No." = "Entry No." THEN
                            ERROR(Text005)
                        ELSE
                            ERROR(Text006);

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
                    IF VoucherRef.Close THEN
                        ERROR(Text004);

                    IF NOT CONFIRM(STRSUBSTNO(Text003, VoucherRef."Auth. Code", VoucherRef."Reference No.", FORMAT(VoucherRef."Amount Transaction"))) THEN
                        EXIT;

                    IF (FORMAT(Rec) = FORMAT(VoucherRef)) OR (("Auth. Code" = VoucherRef."Auth. Code") AND ("Entry No." = VoucherRef."Entry No.")) THEN
                        ERROR(Text007);
                    IF VoucherRef.Close THEN
                        ERROR(Text009);

                    CardProvMgt.Inherit(Rec, VoucherRef);
                    COMMIT;
                end;
            }
            action("Information Inherit")
            {
                Caption = 'Information Inherit';

                trigger OnAction()
                var
                    POSVoucher: Record "FSN POS Card Providers";
                    POStrans: Record "FSN POS Card Prov. VS Customer";
                    Sums_l: Decimal;
                    InPaySum_l: Decimal;
                    Auth: Code[10];
                    EntryNo: Integer;
                begin
                    IF "Date Key" = 0D THEN
                        EXIT;

                    CLEAR(Sums_l);
                    CLEAR(InPaySum_l);
                    IF "Parent Entry No." = 0 THEN BEGIN
                        Auth := "Auth. Code";
                        EntryNo := "Entry No.";
                        Sums_l := "Amount Transaction";
                    END ELSE BEGIN
                        Auth := "Parent Auth. Code";
                        EntryNo := "Parent Entry No.";

                        POSVoucher.RESET;
                        POSVoucher.SETRANGE(POSVoucher."Parent Entry No.", "Entry No.");
                        POSVoucher.SETRANGE(POSVoucher."Parent Auth. Code", "Parent Auth. Code");
                        POSVoucher.CALCSUMS(POSVoucher."Amount Transaction");
                        Sums_l := POSVoucher."Amount Transaction";
                    END;

                    POStrans.RESET;
                    POStrans.SETRANGE(POStrans."Provider Entry No.", EntryNo);
                    POStrans.SETRANGE(POStrans."Auth. Code", Auth);
                    POStrans.CALCSUMS(POStrans.Amount);
                    InPaySum_l := POStrans.Amount;

                    COMMIT;
                    MESSAGE(STRSUBSTNO(Text008, FORMAT("Amount Transaction"), FORMAT(Sums_l), FORMAT(InPaySum_l)));
                end;
            }
            action("Post Diference")
            {
                Caption = 'Post Diference';

                trigger OnAction()
                var
                    InheritRec: Record "FSN POS Card Providers";
                    Sums_l: Decimal;
                begin
                    IF "Amount In Payments" = 0 THEN
                        ERROR(Text013);

                    Sums_l := "Amount Transaction";
                    InheritRec.RESET;
                    IF "Parent Entry No." > 0 THEN BEGIN
                        InheritRec.SETRANGE(InheritRec."Parent Entry No.", "Parent Entry No.");
                        InheritRec.SETRANGE(InheritRec."Parent Auth. Code", "Parent Auth. Code");
                        InheritRec.CALCSUMS("Amount Transaction");
                        Sums_l := InheritRec."Amount Transaction";
                    END;

                    IF NOT CONFIRM(STRSUBSTNO(Text012, "Date Key", "Auth. Code", FORMAT("Amount Transaction"), FORMAT(Sums_l - "Amount In Payments"))) THEN
                        EXIT;

                    VALIDATE(Status, Status::Complete);
                    "Close Diff. Amount" := Sums_l - "Amount In Payments";
                    "User No." := USERID;
                    MODIFY;
                    GET("Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction");//Refresh

                    CurrPage.UPDATE(FALSE);
                end;
            }
        }
    }

    trigger OnClosePage()
    begin
        LookUpOnlySelect := FALSE;
    end;

    trigger OnInit()
    begin
        GlobalsDate := 0D;
        GlobalPendingOnly := FALSE;
        LookUpOnlySelect := FALSE;
    end;

    trigger OnOpenPage()
    begin
        IF NOT LookUpOnlySelect THEN
            SetWorkDate(GlobalsDate, GlobalPendingOnly);

        IF LookUpOnlySelect THEN
            SETRANGE(Close, FALSE);
    end;

    var
     Location: Record "LSC Distribution Location";
        GlobalsDate: Date;
        GlobalPendingOnly: Boolean;
        Text001: Label 'Cancel Links record %1 %2 %3 ?';
        CardProvMgt: Codeunit "FSN POS Card Providers Mgt.";
        Text002: Label 'Cant be canncel this record';
        LookUpOnlySelect: Boolean;
        Text003: Label 'Heredar? \Aut.Code %1  \Referece %2 \Amount  $%3';
        Text004: Label 'Voucher is closed';
        Text005: Label 'Voucher is parent of others vocuhers. Cant inherit';
        Text006: Label 'Voucher already inherit';
        Text007: Label 'Cant be equal voucher';
        Text008: Label 'Voucher amount $%1\Inherit Sums $%2\Used in Payments $%3';
        Text009: Label 'Voucher Destiny is closed';
        Text010: Label 'Cancel by Refund voucher %1 %2 %3 ?';
        Text011: Label 'Cancel by Refund';
        Text012: Label 'Post Difference?\%1 %2 %3\Diff. $%4';
        Text013: Label 'Voucher never used';
        Text014: Label 'Complete, Diffl partial by refund';
        Text015: Label 'Cant be cancel partial in status %1';
        Text016: Label 'Cant be apply like cash partial in status %1';
        Text017: Label 'Apply like Cash partial';
        Text018: Label 'Applied like cash? voucher %1 %2 %3 ?';
        Text019: Label 'Apply like Cash';
        Text020: Label 'Apply to Customer Credit? %1 %2 %3';
        Text021: Label 'Apply to Credit';


    procedure SetWorkDate(pDate: Date; pFilterPending: Boolean)
    begin
        GlobalsDate := pDate;
        GlobalPendingOnly := pFilterPending;

        SETRANGE("Date Key", GlobalsDate);
        IF GlobalPendingOnly THEN BEGIN
            SETRANGE(Close, FALSE);
        END ELSE
            SETRANGE(Close, TRUE);
        CurrPage.UPDATE;
    end;


    procedure LookUPOnly()
    begin
        LookUpOnlySelect := TRUE;
    end;


    procedure GetLastRec(var pVoucherSelect: Record "FSN POS Card Providers")
    begin
        pVoucherSelect := Rec;
    end;
}

