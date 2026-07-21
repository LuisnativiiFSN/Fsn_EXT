page 50026 "FSN Remission Authorization"
{
    // WVILLALTA23SEPT19           - New page

    PageType = StandardDialog;
    SourceTable = "FSN Remission Header";
    ApplicationArea = all;
    UsageCategory = Documents;
    Caption = 'Remission Authorization';

    layout
    {
        area(content)
        {
            group(General)
            {
                field("No."; "No.")
                {
                    Editable = false;
                }
                field("Company Name"; "Company Name")
                {
                    Editable = false;
                }
                field("Insured Name"; "Insured Name")
                {
                    Editable = false;
                }
                field(Amount; RemissionMgt.GetRemissionAmount("Document Type", "No."))
                {
                    Caption = 'Amount';
                    Editable = false;
                    Style = Standard;
                    StyleExpr = TRUE;
                }
                field(AmountIncVAT; RemissionMgt.GetRemissionAmountIncVAT("Document Type", "No."))
                {
                    Caption = 'Amount Inc. VAT';
                    Editable = false;
                }
                field(TotalCompany; RemissionMgt.GetRemissionTotalCompanyInsure("Document Type", "No."))
                {
                    Caption = 'Total Company Insure';
                    Editable = false;
                }
                field(TotalInsured; RemissionMgt.GetRemissionTotalInsured("Document Type", "No."))
                {
                    Caption = 'TotalInsured';
                    Editable = false;
                    Style = StrongAccent;
                    StyleExpr = TRUE;
                }
                field("Authorization No."; "Authorization No.")
                {
                    Editable = AuthorizationBool;
                }
                field("Pre Authorization No."; "Pre Authorization No.")
                {
                    Editable = PreAuthorizationBool;
                }
                field("External Document No."; "External Document No.")
                {
                }
                field("Recipe Date"; "Recipe Date")
                {
                }
            }
        }
    }

    actions
    {
    }

    trigger OnInit()
    begin
        AuthorizationBool := FALSE;
        PreAuthorizationBool := FALSE;
    end;

    trigger OnOpenPage()
    begin
        IF Companys.GET("Company No.") THEN BEGIN
            AuthorizationBool := Companys."Authorize Require";
            PreAuthorizationBool := Companys."Pre Authorize Require";
        END;
    end;

    var
        AuthorizationBool: Boolean;
        PreAuthorizationBool: Boolean;
        RemissionMgt: Codeunit "FSN Remission Mgt.";
        Companys: Record "FSN Company Insurer";
}

