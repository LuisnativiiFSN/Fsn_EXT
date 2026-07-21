page 50069 "FSN Func. WS Request List"
{
    Caption = 'Fun WS Request 1.0 List';
    PageType = List;
    SourceTable = "LSC POS Func. Profile Web Serv";

    layout
    {
        area(content)
        {
            repeater(Control1100409000)
            {
                ShowCaption = false;
                field("Profile ID"; Rec."Profile ID")
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field("Request ID"; Rec."Request ID")
                {
                    ApplicationArea = All;
                    Editable = true;
                }
                field("Local Request"; Rec."Local Request")
                {
                }
                field("Dist. Location"; Rec."Dist. Location")
                {
                    ApplicationArea = All;
                }
                field("Internal Uri"; Rec."Internal Uri")
                {
                }
                field("Interna Override Credentials"; Rec."Interna Override Credentials")
                {
                }
                field("Interna Username"; Rec."Interna Username")
                {
                }
                field("Interna Password"; Rec."Interna Password")
                {
                }
                field("Interna Domain"; Rec."Interna Domain")
                {
                }
            }
        }
    }
}
