table 50026 "FSN POS Card Prov. VS Customer" //50026
{

    fields
    {
        field(10; "Store No."; Code[10])
        {
            Caption = 'Store No.';
        }
        field(20; "POS Terminal No."; Code[10])
        {
            Caption = 'POS Terminal No.';
        }
        field(30; "Transaction No."; Integer)
        {
            Caption = 'Transaction No.';
        }
        field(40; "Line No."; Integer)
        {
            Caption = 'Line No.';
        }
        field(50; "Provider Entry No."; Integer)
        {
            Caption = 'Provider Entry No.';
        }
        field(60; Status; Option)
        {
            Caption = 'Status';
            OptionCaption = 'Nothing,Open,Partial,Completado,Match Reverse,Confirm Pending,Manual Close,CashApply';
            OptionMembers = Nothing,Open,Partial,Complete,MatchReverse,ConfirmPending,ManualClose,CashApply;

            trigger OnValidate()
            begin
                IF Status IN [Status::Complete, Status::MatchReverse, Status::ManualClose, Status::CashApply] THEN
                    Close := TRUE //Complete,MatchReverse,ManualClose,CashApply
                ELSE
                    Close := FALSE;  //Nothing,Open,Partial,ConfirmPending

                IF Status IN [Status::MatchReverse, Status::Open] THEN
                    "Provider Entry No." := 0;
            end;
        }
        field(70; Amount; Decimal)
        {
            Caption = 'Amount';
        }
        field(75; "Amount Pending"; Decimal)
        {
            Caption = 'Amount Pending';
        }
        field(80; "Customer No."; Code[20])
        {
            Caption = 'Customer No.';
        }
        field(85; "Customer Name"; Text[50])
        {
            Caption = 'Customer Name';
        }
        field(90; NCF; Text[20])
        {
            Caption = 'NCF';
        }
        field(95; "Amount Invoice"; Decimal)
        {
            Caption = 'Amount Invoice';
        }
        field(100; "Auth. Code"; Text[10])
        {
            Caption = 'Auth. Code';
        }
        field(110; BIN; Text[10])
        {
            Caption = 'BIN';
        }
        field(120; "Terminal ID"; Text[30])
        {
            Caption = 'Terminal ID';
        }
        field(140; "Authorization Web Ok"; Boolean)
        {
            Caption = 'Authorization Web Ok';
        }
        field(150; "Trans. Date"; Date)
        {
            Caption = 'Trans. Date';
        }
        field(155; "Trans. Time"; Time)
        {
        }
        field(160; "Is Return"; Boolean)
        {
            Caption = 'Is Return';
        }
        field(170; "Staff ID"; Code[20])
        {
            Caption = 'Staff ID';
        }
        field(180; "Process Message"; Text[80])
        {
            Caption = 'Process Message';
        }
        field(190; "Reference No."; Text[20])
        {
        }
        field(200; Close; Boolean)
        {
            Caption = 'Close';
        }
        field(210; "Receipt No."; Code[20])
        {
            Caption = 'Receipt No.';
        }
        field(220; "Consignment Amount"; Decimal)
        {
            Caption = 'Consignment Amount';
        }
        field(240; "Consigment No."; Code[20])
        {
            Caption = 'Consigment No.';
        }
    }

    keys
    {
        key(Key1; "Store No.", "POS Terminal No.", "Transaction No.", "Line No.")
        {
            Clustered = true;
        }
        key(Key2; "Terminal ID", "Auth. Code", BIN, Status, "Trans. Date", Amount)
        {
        }
        key(Key3; "Trans. Date", Close)
        {
        }
        key(Key4; "Provider Entry No.", "Auth. Code")
        {
        }
        key(Key5; "Store No.", "Customer No.", "Trans. Date", Status, Amount)
        {
        }
    }

    fieldgroups
    {
    }

    trigger OnDelete()
    begin
        CheckRec;
    end;

    trigger OnModify()
    begin
        CheckRec;
    end;

    trigger OnRename()
    begin
        CheckRec;
    end;

    var
        Text001: Label 'Cant be MODIFY in status %1';


    procedure CheckRec()
    begin
        IF (Status = Status::Partial) OR xRec.Close OR Close THEN
            ERROR(STRSUBSTNO(Text001, FORMAT(Status)));
    end;
}

