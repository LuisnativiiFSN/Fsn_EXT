codeunit 50066 "Clean Purchase Returns"
{
    Subtype = Normal;
    Permissions =
        tabledata "Purchase Header" = d,
        tabledata "Purchase Line" = r;

    trigger OnRun()
    var
        Deleted: Integer;
    begin
        Deleted := DeleteFullyInvoicedReturns();
        // Si lo ejecutas manualmente, muestra un mensaje. En Job Queue no aparece (GuiAllowed = false).
        if GuiAllowed then
            Message('%1 devoluciones de compra eliminadas.', Deleted);
    end;

    procedure DeleteFullyInvoicedReturns(): Integer
    var
        PurchHeader: Record "Purchase Header";
        Deleted: Integer;
    begin
        PurchHeader.Reset();
        PurchHeader.SetRange("Document Type", PurchHeader."Document Type"::"Return Order");
        PurchHeader.SetFilter(Status, '%1', PurchHeader.Status::Released); // Opcional: permitir abiertas y liberadas
        if PurchHeader.FindSet(true) then
            repeat
                if AllLinesFullyInvoiced(PurchHeader) then begin
                    PurchHeader.Delete(true); // borra cabecera + líneas
                    Deleted += 1;
                end;
            until PurchHeader.Next() = 0;

        exit(Deleted);
    end;

    local procedure AllLinesFullyInvoiced(PurchHeader: Record "Purchase Header"): Boolean
    var
        PurchLine: Record "Purchase Line";
    begin

        PurchLine.Reset();
        PurchLine.SetRange("Document Type", PurchLine."Document Type"::"Return Order");
        PurchLine.SetRange("Document No.", PurchHeader."No.");
        if PurchLine.FindSet() then
            repeat
                // Ignoramos líneas sin cantidad (comentarios, etc.)
                if (PurchLine.Type <> PurchLine.Type::" ") and (PurchLine.Quantity <> 0) then
                    if Abs(PurchLine.Quantity - PurchLine."Quantity Invoiced") > 0 then
                        exit(false);
            until PurchLine.Next() = 0;

        exit(true);
    end;
}

