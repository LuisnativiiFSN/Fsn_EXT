tableextension 50090 MyExtension extends "LSC Store"
{
    fields
    {
        field(5000; "FSN minimum day"; Integer)
        {
            Caption = 'Dia Minimo';
            DataClassification = ToBeClassified;
        }
        field(5001; "FSN maximum day"; Integer)
        {
            Caption = 'Dia Maximo';
            DataClassification = ToBeClassified;
        }
        field(5002; "FSN Grupo No. Stock Level"; Enum "FSN Grupo No. Stock Level")
        {
            Caption = 'FSN Grupo No. Stock Level';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}