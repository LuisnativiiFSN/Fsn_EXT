pageextension 50018 PageExtension50018 extends "Warehouse Receipts"
{
    layout
    {
        addafter("Assigned User ID")
        {
            field("Vendor Shipment No.42150"; Rec."Vendor Shipment No.")
            {
                ApplicationArea = All;
            }
        }
    }


}