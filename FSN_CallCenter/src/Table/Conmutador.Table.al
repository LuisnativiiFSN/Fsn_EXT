table 50060 "FSN Commutator"
{

    fields
    {
        field(10; "Host Name"; Text[50])
        {
        }
        field(20; Extension; Integer)
        {
        }
        field(30; Description; Text[50])
        {
        }
        field(40; StaffID; Text[50])
        {
            Editable = false;
        }
        field(50; Date; Date)
        {
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "Host Name")
        {
            Clustered = true;
        }
    }
    fieldgroups
    {
    }
}

