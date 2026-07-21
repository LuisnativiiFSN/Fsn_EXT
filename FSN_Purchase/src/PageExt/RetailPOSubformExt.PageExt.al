pageextension 50054 "FSN RetailPOSubPageExt" extends "LSC Retail PO Subpage"
{
    layout
    {
        addbefore("No.")
        {
            field("FSN Barcode No."; "FSN Barcode No.")
            {
                trigger OnValidate()
                var
                    Barcodes2: Record "LSC Barcodes";
                begin
                    if Barcodes2.Get("FSN Barcode No.") then begin
                        Validate("No.", Barcodes2."Item No.");
                        Validate("Unit of Measure", Barcodes2."Unit of Measure Code");
                    end;
                end;
            }
        }
        addbefore(Description)
        {
            field("FSN Attrib 1 Code"; "FSN Attrib 1 Code") { }
        }
    }
    actions
    {
    }
    trigger OnModifyRecord(): boolean
    var
        Item2: Record Item;
    begin
        if (Rec."No." <> '') and Item2.Get(Rec."No.") then
            "FSN Attrib 1 Code" := Item2."LSC Attrib 1 Code";

    end;
}