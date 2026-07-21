pageextension 50095 "FSN Stock Request List_Ext" extends "LSC Stock Request List"
{
    Caption = 'FSN Stock Request List Ext';
    actions
    {
        addLast(Processing)
        {
            action("FSN authorization")
            {
                Caption = 'FSN authorization';
                Image = Purchase;
                Promoted = true;
                PromotedCategory = Process;
                PromotedIsBig = true;
                RunObject = Page "FASANI Stock Request";
                RunPageLink = "No." = FIELD("No.");
            }
        }
    }
}