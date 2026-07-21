page 50149 "FSN PITS Sub Line"
{
    Caption = 'PITS Sub Line';
    PageType = List;
    SourceTable = "PITS Sub Line";
    ApplicationArea = all;
    UsageCategory = Administration;
    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("No."; "No.")
                {
                    Caption = 'No.', comment = 'NLB="No"';
                }
                field("Line No."; "Line No.")
                {
                    Caption = 'Line No.', comment = 'NLB="Line No"';
                }
                field("Sub Line No."; "Sub Line No.")
                {
                    Caption = 'Sub Line No.', comment = 'NLB="Sub Line No"';
                }
                field("No. Remision"; "No. Remision")
                {
                    Caption = 'No. Remision', comment = 'NLB="No. Remision"';
                }
                field("Item No."; "Item No.")
                {
                    Caption = 'Item No.', comment = 'NLB="Item No"';
                }
                field(Lote; Lote)
                {
                    Caption = 'Lote', comment = 'NLB="Lote"';
                }

                field("Quantity"; "Quantity")
                {
                    Caption = 'Quantity', comment = 'NLB="Quantity"';
                }
                field("Expiration Date"; "Expiration Date")
                {
                    Caption = 'Expiration Date', comment = 'NLB="Expiration Date"';
                }
            }
        }
    }

    actions
    {
    }
}

