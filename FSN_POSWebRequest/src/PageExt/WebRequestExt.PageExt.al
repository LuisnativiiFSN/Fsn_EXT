pageextension 50092 "FSN POS Funcitonality Ext" extends "LSC POS Func. Profile List"
{
    layout
    {
    }

    actions
    {
        addafter("Where Used")
        {
            action("FSN WS Request")
            {
                ApplicationArea = All;
                RunObject = page "FSN Func. WS Request List";
                RunPageLink = "Profile ID" = field("Profile ID");
                trigger OnAction()
                begin

                end;
            }
        }
    }
}