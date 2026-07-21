pageextension 50070 "FSN ReplenSetupExt" extends "LSC Replen. Setup"
{
    layout
    {
        addafter("Open-to-Buy")
        {
            group("FSN")
            {
                Caption = 'FSN';
                field("FSN Consolidate Serie No."; "FSN Consolidate Serie No.")
                {
                }
                field("FSN Approach Adjustment Type"; "FSN Approach Adjustment Type")
                {
                }
                field("FSN Approach Multiple %"; "FSN Approach Multiple %")
                {
                }
                field("FSN Transfer Consolidate No."; "FSN Transfer Consolidate No.")
                {
                }
            }
        }
    }
}