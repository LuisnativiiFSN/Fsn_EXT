table 50070 "FSN Sales Channel"
{
    fields
    {
        field(10; "Receipt No"; Code[20])
        {
        }
        field(11; "POS Terminal No"; Code[20])
        {
        }
        field(12; "Store No"; Code[20])
        {
        }
        field(20; PhoneNo; Text[20])
        {
        }
        field(30; Date; Date)
        {
        }
        field(40; Time; Time)
        {
        }
        field(50; SalesStaff; Code[20])
        {
        }
        field(51; "Amount Incl. VAT"; Decimal)
        {
        }
        field(52; TypeChannel; Code[50])
        {
        }
        field(60; SalesChannel; Text[50])
        {
        }
        field(80; Importance; Boolean)
        {
            Enabled = false;
        }
        field(81; Ticket; Code[30])
        {
        }
        field(82; "Pending Processing"; Boolean)
        {
            Caption = 'Pending Processing';
        }
        field(90; Comment; Text[250])
        {
            Caption = 'Comment';
        }
        field(100; Voided; Boolean)
        {
            Caption = 'Voided';
        }
    }

    keys
    {
        key(Key1; "Receipt No")
        {
            Clustered = true;
        }
        key(Key2; "Pending Processing")
        {
        }
    }

    fieldgroups
    {
    }

    var
        POSSetupExt: Record "FSN POS Setup Extend";
}

