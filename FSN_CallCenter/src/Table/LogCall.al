table 50030 "FSN Change Log Transaction"
{

    fields
    {
        field(10; "Entry No."; BigInteger)
        {
            Editable = false;
        }
        field(20; "Receipt No."; Code[20])
        {
        }
        field(30; "Phone No."; Text[20])
        {
        }
        field(40; "Date"; Date)
        {
        }
        field(50; "Log Time"; Time)
        {
        }
        field(60; "User ID"; Code[50])
        {
        }
        field(70; "Staff ID"; Code[50])
        {
        }
        field(80; "Type of Change"; Option)
        {
            OptionMembers = ,Deletion,Insertion,Modification;
        }
        field(90; "Action"; Text[250])
        {
        }
    }

    keys
    {
        key(Key1; "Entry No.", "Receipt No.")
        {
            Clustered = true;
        }
    }

    var
        myInt: Integer;

    trigger OnInsert()
    begin

    end;

    trigger OnModify()
    begin

    end;

    trigger OnDelete()
    begin

    end;

    trigger OnRename()
    begin

    end;

}