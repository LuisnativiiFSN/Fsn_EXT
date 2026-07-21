pageextension 50102 "FSN Whse. Receipt Subform" extends "Whse. Receipt Subform"
{
    layout
    {
        // Add changes to page layout here
        addafter(Description)
        {
            field(Fech_V; Fech_V)
            {
                Caption = 'Fecha vencimiento';
                Editable = false;
            }

            field("No. Pedido"; "No. Pedido")
            {
                Caption = 'No. Lote';
                Editable = false;
            }
        }
    }

    actions
    {
        // Add changes to page actions here
    }

    var
        myInt: Integer;
        Fech_V, Fech : Date;
        "No. Pedido": Code[20];

    trigger OnAfterGetRecord()
    var
        myInt: Integer;
        Pits: Record PITS_WMScd2suc;

    begin
        Pits.Reset();
        Pits.SetRange("No.", Rec."Source No.");
        Pits.SetRange("Line No.", Rec."Source Line No.");
        if Pits.FindFirst() then begin
            Fech_V := Pits."Ending Date";
            //Fech_V := DT2Date(Pits."Date Updated");
            "No. Pedido" := Pits."No. Pedido"
        end;
    end;
}