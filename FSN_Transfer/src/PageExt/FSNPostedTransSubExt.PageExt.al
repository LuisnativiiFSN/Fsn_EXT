pageextension 50099 "FSN Posted Trans.Rcpt. Subform" extends "Posted Transfer Rcpt. Subform"
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
        Fech_V: Date;
        "No. Pedido": Code[20];

    trigger OnAfterGetRecord()
    var
        myInt: Integer;
        Pits: Record PITS_WMScd2suc;
    begin
        Pits.Reset();
        Pits.SetRange("No.", Rec."Transfer Order No.");
        Pits.SetRange("Item No.", Rec."Item No.");
        if Pits.FindFirst() then begin
            Fech_V := Pits."Ending Date";
            "No. Pedido" := Pits."No. Pedido"
        end;
    end;
}