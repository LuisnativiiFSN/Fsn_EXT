tableextension 50067 "FSN POS Transac Robot TableExt" extends "LSC POS Transaction"
{
    fields
    {
        field(5001; "FSN Status Robot"; Option)
        {
            Caption = 'FSN Status Robot';
            OptionCaption = 'No Procesado,Procesado';
            OptionMembers = "No Procesado",Procesado;
        }
        field(5002; "FSN Assigned PosTerminalNo"; Code[10])
        {
            Caption = 'FSN Assigned PosTerminalNo';
        }
        field(5003; "FSN state of preparation"; Option)
        {
            Caption = 'FSN state of preparation';
            OptionCaption = 'No Preparado,Preparando';
            OptionMembers = "No Preparado",Preparando;
        }
        field(5004; "FSN Ventanilla"; Integer)
        {
            Caption = 'FSN Ventanilla';
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