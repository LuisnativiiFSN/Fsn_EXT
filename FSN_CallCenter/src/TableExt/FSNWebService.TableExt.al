tableextension 50066 "FSN WebServiceTableExtend" extends "FSN WebServiceTable"
{
    fields
    {
        field(210; "C807 peso"; Decimal)
        {
            DataClassification = ToBeClassified;
        }
        field(220; "Unidad de medida"; Text[20])
        {
            DataClassification = ToBeClassified;
        }
        field(230; "C807 Guia"; Code[100])
        {
            DataClassification = ToBeClassified;
        }
        field(240; "C807 Recolecta"; Code[100])
        {
            DataClassification = ToBeClassified;
        }
        field(250; "C807 Status"; Boolean)
        {
            DataClassification = ToBeClassified;
        }
    }

    keys
    {
        // Add changes to keys here
    }

    fieldgroups
    {
        // Add changes to field groups here
    }

    var
        myInt: Integer;
}