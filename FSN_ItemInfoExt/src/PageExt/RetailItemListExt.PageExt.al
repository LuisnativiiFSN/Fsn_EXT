pageextension 50063 "FSN RetailItemListExt" extends "LSC Retail Item List"
{
    layout
    {
        addafter(Description)
        {
            field("Description 2"; "Description 2")
            {
                ApplicationArea = All;
                Editable = false;
            }
        }
    }

    actions
    {
        addafter("Ac&tions")
        {
            action(ItemInfoType)
            {
                Caption = 'Item Info. Type';
                Image = AdjustEntries;
                RunObject = Page "FSN Item Information Type";
            }
            action(ItemInfoExtend)
            {
                Caption = 'Item Information Add';
                Image = Add;
                RunObject = Page "FSN Item Information Extend";
                RunPageLink = "No." = FIELD("No.");
            }
            action(UpdateAllIngredient)
            {
                ApplicationArea = All;
                Caption = 'Update all ingredient';
                Image = Add;
                trigger OnAction()
                var
                    Item_l: Record Item;
                    ItemInfoEx: Codeunit "FSN Item Info. Extend";
                    lTxt1: Label 'Do you want to upgrade all items?\It will take a few minutes';
                begin
                    if not Confirm(lTxt1) then
                        exit;
                    Item_l.Reset();
                    if Item_l.Find('-') then
                        repeat
                            ItemInfoEx.UpdateItemDescription2(Item_l."No.");
                        until Item_l.Next() = 0;
                end;
            }
            action("Ecommerce Setup")
            {
                Caption = 'Ecommerce Setup';
                Image = XMLSetup;

                trigger OnAction()
                var
                    PAGEEcommerceSetup: Page "FSN Ecommerce Info Extend.";
                begin
                    PAGEEcommerceSetup.SetMode(4);
                    PAGEEcommerceSetup.RUN;
                end;
            }
            action("Offer Extend")
            {
                Caption = 'Offer Extend';
                Image = Discount;

                trigger OnAction()
                begin
                    page.run(page::"FSN Fasani Offer Extended");
                end;
            }
        }
    }
}
