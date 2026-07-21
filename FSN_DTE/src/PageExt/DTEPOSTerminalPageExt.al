pageextension 50043 "FSN DTE POSTerminalExt" extends "LSC POS Terminal Card"
{
    layout
    {
        addafter(General)
        {
            group("DTE")
            {
                field("DTE CodeSellingPointMH"; "DTE CodeSellingPointMH") { }
            }
        }
    }
    actions
    {
    }
}