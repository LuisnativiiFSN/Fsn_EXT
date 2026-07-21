table 50061 "FSN Call Entry"
{

    fields
    {
        field(10; UniqueID; Text[50])
        {
            Editable = false;
        }
        field(20; Extension; Integer)
        {
            Editable = false;
        }
        field(30; "Phone No."; Text[20])
        {
            Editable = false;
        }
        field(40; "Date"; Date)
        {
        }
        field(50; "Start Time"; Time)
        {
            Editable = false;
        }
        field(60; "Ending Time"; Time)
        {
            Editable = false;

            trigger OnValidate()
            begin
                if "Start Time" <> 0T then
                    "Duration" := "Ending Time" - "Start Time";
            end;
        }
        field(70; "Duration"; Duration)
        {
            Enabled = false;
        }
        field(80; Finalized; Boolean)
        {
            Editable = false;
        }
        field(81; Agent; Integer)
        {
        }
        field(82; AppliedbyReceiptNo; Text[30])
        {
        }
        field(90; Registered; Boolean)
        {
        }
        field(100; "Call Type"; option)
        {
            OptionMembers = Inbound,Outbound,Confirmation;
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        key(Key1; UniqueID, Extension)
        {
            Clustered = true;
            SQLIndex = UniqueID, Extension;
        }
        key(Key2; AppliedbyReceiptNo, "Phone No.", Extension)
        {
        }
    }

    fieldgroups
    {
    }
}

