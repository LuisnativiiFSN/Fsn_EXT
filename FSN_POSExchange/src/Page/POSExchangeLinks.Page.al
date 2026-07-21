page 50039 "FSN POS Exchange Links"
{

    Caption = 'FSN POS Exchange Links';
    PageType = List;
    SourceTable = "FSN POS Exchange Item Link";
    ApplicationArea = All;
    UsageCategory = Administration;

    layout
    {
        area(content)
        {
            repeater(Group)
            {
                field("Item No."; "Item No.")
                {
                }
                field("Unit of Measure"; "Unit of Measure")
                {
                    Caption = 'Unit of Measure';
                }
                field("POS Exchange No."; "POS Exchange No.")
                {
                    Caption = 'POS Exchange No.';
                }
                field(GetExchDescription; GetExchDescription(Rec))
                {
                    Caption = 'Exchange Description';
                }
                field("Use Inventory"; "Use Inventory")
                {
                    Caption = 'Use Inventory';
                    Editable = false;
                }
                field(ItemDescription; GetItemDescription("Item No."))
                {
                    Caption = 'Item Description';
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action(ExchangeSetup)
            {
                Caption = 'Exchange Setup';
                Image = Setup;
                RunObject = Page "FSN POS Exchange Setup";
            }
        }
    }
}

