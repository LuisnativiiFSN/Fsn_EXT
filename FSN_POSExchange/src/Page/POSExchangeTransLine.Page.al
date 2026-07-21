page 50034 "FSN POS Exchange Trans. Line"
{

    Caption = 'FSN POS Exchange Trans. Line';
    PageType = List;
    SourceTable = "FSN POS Exchange Transaction";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Receipt No."; "Receipt No.")
                {
                    Editable = false;
                }
                field("Line No."; "Line No.")
                {
                    Editable = false;
                }
                field("Barcode No."; "Barcode No.")
                {
                    Caption = 'Barcode No.';
                }
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                }
                field(ItemName; GetItemDescription("Item No."))
                {
                    Caption = 'Item Description';
                }
                field(Quantity; Quantity)
                {
                }
                field("POS Terminal No."; "POS Terminal No.")
                {
                    Editable = false;
                }
                field(Status; Status)
                {
                    Editable = false;
                }
                field("Customer No."; "Customer No.")
                {
                    Editable = false;
                }
                field("Customer Sub Code"; "Customer Sub Code")
                {
                }
                field("POS Exchange No."; "POS Exchange No.")
                {
                    Style = Strong;
                    StyleExpr = TRUE;
                }
            }
        }
    }

    actions
    {
    }

    trigger OnClosePage()
    var
        POSExTransaction_l: Record "FSN POS Exchange Transaction";
    begin
        POSExTransaction_l.RESET;
        POSExTransaction_l.SETRANGE(POSExTransaction_l."Receipt No.", Globals."Receipt No.");
        IF POSExTransaction_l.FINDSET THEN
            REPEAT
                IF POSExTransaction_l."POS Exchange No." = '' THEN
                    ERROR(STRSUBSTNO(gText005, FIELDCAPTION("POS Exchange No."), FORMAT(POSExTransaction_l."Line No.")));
            UNTIL POSExTransaction_l.NEXT = 0;
    end;

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        ExchangeLines: Record "FSN POS Exchange Transaction";
    begin
        IF NOT (Globals."Receipt No." <> '') THEN
            ERROR(gText001);
        IF Globals."Customer No." = '' THEN
            ERROR(gText004);

        "Receipt No." := Globals."Receipt No.";
        "Store No." := Globals."Store No.";
        "POS Terminal No." := Globals."POS Terminal No.";
        "Customer No." := Globals."Customer No.";
        "Staff ID" := Globals."Staff ID";
        "Sales Staff" := Globals."Sales Staff";
        "Transaction Date" := Globals."Trans. Date";


        IF NOT (("Receipt No." <> '') AND ("Store No." <> '') AND ("POS Terminal No." <> '')) THEN
            ERROR(STRSUBSTNO(gText002, FIELDCAPTION("Receipt No."), FIELDCAPTION("Store No."), FIELDCAPTION("POS Terminal No.")));

        ExchangeLines.RESET;
        ExchangeLines.SETCURRENTKEY("Receipt No.", "Transaction No.", "Line No.", "Store No.", "POS Terminal No.");
        ExchangeLines.SETRANGE(ExchangeLines."Receipt No.", Globals."Receipt No.");
        IF ExchangeLines.FINDLAST THEN
            "Line No." := ExchangeLines."Line No." + 10000
        ELSE
            "Line No." := 10000;
    end;

    trigger OnModifyRecord(): Boolean
    var
        POSExchLinks: Record "FSN POS Exchange Item Link";
    begin
        IF "Item No." <> '' THEN BEGIN
            POSExchLinks.RESET;
            POSExchLinks.SETRANGE(POSExchLinks."Item No.", "Item No.");
            IF NOT POSExchLinks.FINDFIRST THEN
                MESSAGE(STRSUBSTNO(gText003, GetItemDescription("Item No.")));
        END;
    end;

    trigger OnOpenPage()
    var
        UserRetail: Record "LSC Retail User";
    begin
        IF Globals."Receipt No." <> '' THEN BEGIN
            FILTERGROUP(2);
            SETRANGE("Receipt No.", Globals."Receipt No.");
            FILTERGROUP(0);
        END
        ELSE
            IF UserRetail.GET(USERID) THEN
                IF UserRetail."Store No." <> '' THEN BEGIN
                    FILTERGROUP(2);
                    SETRANGE("Store No.", UserRetail."Store No.");
                    FILTERGROUP(0);
                END;
    end;

    var
        Globals: Record "LSC POS Transaction";
        gText001: Label 'Receipt references not exists!.';
        gText002: Label 'Fields %1, %2 or %3 cant be empty.';
        gText003: Label 'Item %1 is not configured for exchange.';
        gText004: Label 'Transaction must have load Customer';
        gText005: Label 'Field %1 cant be empty, delete records for totalizer. Line %2';

    procedure SETGLOBALVALUE(POSTransaction_: Record "LSC POS Transaction")
    begin
        Globals := POSTransaction_;
    end;
}

