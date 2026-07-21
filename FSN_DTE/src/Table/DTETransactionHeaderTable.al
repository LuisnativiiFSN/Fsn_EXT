/// <summary>
/// Table FSN DTE Transaction Header (ID 50015).
/// </summary>
table 50021 "FSN DTE Transaction Header"
{
    DataClassification = ToBeClassified;
    Access = Public;

    fields
    {
        field(1; "Store No."; Code[20])
        {
        }
        field(2; "POS Terminal No."; Code[10])
        {
        }
        field(3; "Transaction No."; Integer)
        {
            Caption = 'Transaction No.';
        }
        field(4; "DTE AuthNumber"; Code[36])
        {
            Caption = 'DTE AuthNumber';
        }

        field(5; "DTE IssuedTimeStamp"; Text[20])
        {
            Caption = 'DTE IssuedTimeStamp';
        }
        field(6; "DTE EnrolledTimeStamp"; Text[20])
        {
            Caption = 'DTE EnrolledTimeStamp';
        }

        field(7; "DTE Invoice"; Code[31])
        {
            Caption = 'DTE Invoice';
        }
        field(9; "Document Type"; Code[2])
        {
            Caption = 'Document Type';
        }
        field(10; "Creating Date"; Date)
        {
            Caption = 'Creating Date';
        }
        field(11; "Status"; Option)
        {
            OptionMembers = "Send","Anulled";
            OptionCaption = 'Send,Anulled';
            Caption = 'Status';
        }
        field(12; "Replication Counter"; Integer)
        {
            Caption = 'Replication Counter';
            //AutoIncrement = true;
            trigger OnValidate()
            var
                FSNDteHeader: Record "FSN DTE Transaction Header";
            begin
                FSNDteHeader.RESET;
                FSNDteHeader.SETCURRENTKEY("Replication Counter");
                IF FSNDteHeader.FINDLAST THEN
                    "Replication Counter" := FSNDteHeader."Replication Counter" + 1
                ELSE
                    "Replication Counter" := 1;
            end;

        }
        field(13; "Signature Validation"; Text[50])
        {
            Caption = 'Signature Validation';
            DataClassification = ToBeClassified;
        }
        field(14; "Receipt No."; Code[20])
        {
            Caption = 'Receipt No.';
        }
    }

    keys
    {
        key(PK; "Store No.", "POS Terminal No.", "Transaction No.")
        {
            Clustered = true;
        }
        key(index1; "Store No.", "POS Terminal No.", "Receipt No.")
        {

        }
        key(index2; "Replication Counter")
        {
        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnModify()
    begin
        VALIDATE("Replication Counter");
    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin
        VALIDATE("Replication Counter");
    end;

}