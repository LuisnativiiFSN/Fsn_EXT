table 50025 "FSN POS Card Providers" //50025
{
    fields
    {
        field(5; "Record Type"; Option)
        {
            Caption = 'Record Type';
            OptionCaption = 'Load,Manual,Duplicate,Manual Refund';
            OptionMembers = Load,Manual,Duplicate,ManualRefund;
        }
        field(10; "Date Key"; Date)
        {
            Caption = 'Date Key';
        }
        field(20; "Terminal ID"; Code[20])
        {
        }
        field(30; "Auth. Code"; Code[10])
        {
            Caption = 'Auth. Code';
        }
        field(40; "Reference No."; Code[20])
        {
            Caption = 'Reference No.';
        }
        field(45; "Audit Number"; Text[30])
        {
            Caption = 'Audit Number';
        }
        field(50; "Card Mask"; Text[30])
        {
            Caption = 'Card Mask';
        }
        field(60; "Retailer ID"; Text[30])
        {
        }
        field(65; "Trans. Time Text"; Text[20])
        {
            Caption = 'Trans. Time Text';
        }
        field(70; "Amount Transaction"; Decimal)
        {
            Caption = 'Amount Transaction';
        }
        field(75; "Commission Percent"; Decimal)
        {
            Caption = 'Commission Percent';
        }
        field(80; "Amount Commission"; Decimal)
        {
            Caption = 'Amount Commission';
        }
        field(85; "Provider Name"; Text[30])
        {
            Caption = 'Provider Name';
            TableRelation = "FSN POS Setup Extend"."Value No." WHERE(Type = CONST(CardManager), "Line Type" = CONST(Provider));
            ValidateTableRelation = true;
        }
        field(86; "Trans. Type"; Text[30])
        {
            Caption = 'Trans. Type';
            TableRelation = "FSN POS Setup Extend"."Value No." WHERE(Type = CONST(CardManager), "Line Type" = CONST("Type Card Trans."));
            ValidateTableRelation = true;
        }
        field(90; "Extra Data 1"; Text[30])
        {
            Caption = 'Extra Data 1';
        }
        field(100; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(110; Status; Option)
        {
            OptionCaption = 'Open,Partial,Complete,MatchReverse,Confirm Pending,Cancelled,Inherit,CashApply,ApplyCreditCustomer';
            OptionMembers = Open,Partial,Complete,MatchReverse,ConfirmPending,Cancelled,Inherit,CashApply,ApplyCreditCustom;

            trigger OnValidate()
            begin
                IF Status IN [Status::Complete, Status::MatchReverse, Status::Cancelled, Status::Inherit, Status::CashApply, Status::ApplyCreditCustom] THEN BEGIN
                    Close := TRUE //Complete,MatchReverse,Cancelled,Inherit,CashApply
                END ELSE BEGIN
                    Close := FALSE;//Open,Partial,ConfirmPending
                END;
            end;
        }
        field(120; "User No."; Code[50])
        {
        }
        field(130; "Count Records"; Integer)
        {
            Caption = 'Count Records';
        }
        field(140; "Is Reverse"; Boolean)
        {
            Caption = 'Is Reverse';
        }
        field(150; "Amount In Payments"; Decimal)
        {
            Caption = 'Amount In Payments';
        }
        field(160; Close; Boolean)
        {
            Caption = 'Close';
        }
        field(170; "Parent Entry No."; Integer)
        {
        }
        field(180; "Parent Auth. Code"; Code[10])
        {
        }
        field(185; "Parent Amt. Comission"; Decimal)
        {
        }
        field(186; "Parent Amount"; Decimal)
        {
        }
        field(190; "Store In Setup"; Code[10])
        {
            Caption = 'Store In Setup';
        }
        field(200; "Store Apply"; Code[10])
        {
            Caption = 'Store Apply';
        }
        field(210; "Close Diff. Amount"; Decimal)
        {
            Caption = 'Close Diff. Amount';
        }
        field(220; "Close Diff. Refund"; Decimal)
        {
            Caption = 'Close Diff. Refund';
        }
        field(230; "Close Diff. Like Cash"; Decimal)
        {
            Caption = 'Close Diff. Like Cash';
        }
        field(240; "Last Customer No."; Code[20])
        {
            Caption = 'Last Customer No.';
        }
    }

    keys
    {
        key(Key1; "Record Type", "Date Key", "Terminal ID", "Auth. Code", "Reference No.", "Amount Transaction")
        {
            Clustered = true;
        }
        key(Key2; Status, "Amount Transaction", "Date Key", "Store In Setup", "Card Mask")
        {
        }
        key(Key3; "Entry No.")
        {
        }
        key(Key4; Close, "Date Key")
        {
        }
        key(Key5; "Parent Entry No.", "Parent Auth. Code")
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        CheckFields;
        IF "Parent Entry No." > 0 THEN
            ERROR(Text004);
    end;

    trigger OnInsert()
    begin
        SetEntryNo;
        "Is Reverse" := "Amount Transaction" < 0;

        IF (("Amount Transaction" < 0) AND NOT "Is Reverse") OR
          (("Amount Transaction" > 0) AND "Is Reverse") THEN
            ERROR(Text003);
        SetTerminaStore;
    end;

    trigger OnModify()
    begin
        CheckFields;
        IF (("Amount Transaction" < 0) AND NOT "Is Reverse") OR
          (("Amount Transaction" > 0) AND "Is Reverse") THEN
            ERROR(Text003);
        IF "Parent Entry No." > 0 THEN
            ERROR(Text004);
    end;

    trigger OnRename()
    begin
        CheckFields;
        IF (("Amount Transaction" < 0) AND NOT "Is Reverse") OR
          (("Amount Transaction" > 0) AND "Is Reverse") THEN
            ERROR(Text003);

        IF "Parent Entry No." > 0 THEN
            ERROR(Text004);
    end;

    var
        Text001: Label 'Cant be modify in status %1';
        Text002: Label 'Cant be delete in status %1';
        POSCardProviders: Record "FSN POS Card Providers";//"50025";
        Text003: Label 'Is Reverse must be negative, Positive for buy';
        Text004: Label 'Cant be MODIFY in status active inherit';
        POSSetupExtend: Record "FSN POS Setup Extend";


    procedure SetEntryNo()
    begin
        Status := 0;
        IF "Entry No." = 0 THEN BEGIN
            POSCardProviders.RESET;
            POSCardProviders.SETCURRENTKEY("Entry No.");
            IF POSCardProviders.FINDLAST THEN
                "Entry No." := POSCardProviders."Entry No." + 1
            ELSE
                "Entry No." := 1;
        END;
    end;


    procedure CheckFields()
    begin
        "Is Reverse" := "Amount Transaction" < 0;
        IF Close OR xRec.Close OR (xRec.Status = xRec.Status::Partial) THEN
            ERROR(STRSUBSTNO(Text001, FORMAT(Status)));

        SetTerminaStore;
    end;


    procedure SetTerminaStore()
    var
        POSSetup2: Record "FSN POS Setup Extend"; //"50028";
    begin
        IF ("Terminal ID" <> '') AND ("Store In Setup" = '') AND ("Date Key" <> 0D) THEN BEGIN
            POSSetupExtend.RESET;
            POSSetupExtend.SETCURRENTKEY("Value No.", "Store No.", "From Date", "To Date");
            POSSetupExtend.SETRANGE(POSSetupExtend.Type, POSSetupExtend.Type::CardManager);
            POSSetupExtend.SETRANGE(POSSetupExtend."Line Type", POSSetupExtend."Line Type"::"Terminal Card");
            POSSetupExtend.SETRANGE(POSSetupExtend."Value No.", "Terminal ID");
            POSSetupExtend.SETFILTER(POSSetupExtend."Store No.", '<>%1', '');
            POSSetupExtend.SETFILTER(POSSetupExtend."From Date", '=%1|<=%2', 0D, "Date Key");
            POSSetupExtend.SETFILTER(POSSetupExtend."To Date", '=%1|>=%2', 0D, "Date Key");
            IF POSSetupExtend.FIND('-') THEN
                "Store In Setup" := POSSetupExtend."Store No."
            ELSE BEGIN
                POSSetupExtend.SETRANGE(POSSetupExtend."Line Type", POSSetupExtend."Line Type"::"Retailer Card");
                POSSetupExtend.SETRANGE(POSSetupExtend."Value No.", "Retailer ID");
                IF POSSetupExtend.FIND('-') THEN
                    "Store In Setup" := POSSetupExtend."Store No.";
            END;
        END;
    end;
}

