pageextension 50002 PageExtension50002 extends "LSC Membership Card"
{
    layout
    {
        addafter("Contact No.")
        {
            field("FSN Beneficiary28972"; Rec."FSN Beneficiary")
            {
                ApplicationArea = All;
            }
        }
        addafter(Status)
        {
            field("FSN SalesStaff42120"; Rec."FSN SalesStaff")
            {
                ApplicationArea = All;
            }
            field("FSN Sales Document No.15760"; Rec."FSN Sales Document No.")
            {
                ApplicationArea = All;
            }
        }
        addafter("Reason Blocked")
        {
            field("FSN Renewal Date03917"; Rec."FSN Renewal Date")
            {
                ApplicationArea = All;
            }
        }
    }
}
