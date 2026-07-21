pageextension 50082 "FSN ItemLoadReferenceExt" extends "LSC Retail Item List"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addafter("Ac&tions")
        {
            action(LoadItemReference)
            {
                Caption = 'Item Load Reference';
                Image = Discount;
                RunObject = Page "FSN Load Item With Reference";
            }
        }
    }
}