tableextension 50120 "FSN Picking Receiving LinExt" extends "LSC Picking / Receiving lines"
{
    fields
    {
        field(55000; "FSN Revisar Costo"; Boolean)
        {
            Caption = 'Revisar Costo';
            DataClassification = ToBeClassified;
        }
        field(55001; "FSN Escaneo Pendiente"; Boolean)
        {
            Caption = 'FSN Escaneo Pendiente';
            DataClassification = ToBeClassified;
        }
        field(55002; "FSN Orden Facturado"; Integer)
        {
            Caption = 'FSN Orden Facturado';
            DataClassification = ToBeClassified;
        }
        field(55003; "FSN Cantidad DTE"; Integer)
        {
            Caption = 'Cantidad DTE';
            DataClassification = ToBeClassified;
        }
    }

    var
        myInt: Integer;
}