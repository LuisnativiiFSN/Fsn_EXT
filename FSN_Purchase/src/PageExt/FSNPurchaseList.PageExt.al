pageextension 50148 "FSN Purchase List " extends "Purchase List"
{
    layout
    {
        addafter("Assigned User ID")
        {
            field("Order Date35017"; Rec."Order Date")
            {
                ApplicationArea = All;
            }
            field(Status42783; Rec.Status)
            {
                ApplicationArea = All;
            }
            field("FSN Consolidate No.58184"; Rec."FSN Consolidate No.")
            {
                ApplicationArea = All;
            }
        }
    }
}
