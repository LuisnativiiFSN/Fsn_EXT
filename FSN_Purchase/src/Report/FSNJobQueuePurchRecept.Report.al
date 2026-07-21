report 50015 "FSN Job Queue Purch Recept"
{
    Caption = 'FSN Job Queue Purchase Receipt';
    UsageCategory = ReportsAndAnalysis;

    dataset
    {
        dataitem(Integer; "Purchase Header")
        {
            column("Filter"; "No.")
            {
            }

        }
    }

    requestpage
    {
        layout
        {
            area(content)
            {
                group(Group)
                {

                }
            }
        }
    }

    trigger OnPreReport()
    begin
        // Add any initialization code here
    end;

    trigger OnPostReport()
    begin
        // Add any cleanup code here
    end;
}