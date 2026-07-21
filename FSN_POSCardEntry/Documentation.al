// Welcome to your new AL extension.
// Remember that object names and IDs should be unique across all extensions.
// AL snippets start with t*, like tpageext - give them a try and happy coding!


/*
-> GET BIN LIST (PROBAR CON Texto plano)
-> BAC (DLL)
-> SERFINSA (DLL)

*/
/*page 50099 MyPage
{
    PageType = Card;
    ApplicationArea = All;
    UsageCategory = Administration;
    SourceTable = "LSC POS Transaction";

    layout
    {
        area(Content)
        {
            group(GroupName)
            {
                field(Name; "Receipt No.")
                {
                    ApplicationArea = All;

                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ActionName)
            {
                ApplicationArea = All;

                trigger OnAction()
                var
                    c: Codeunit "LSC POS Transaction";
                begin

                end;
            }
        }
    }

    var
        myInt: Integer;
}
*/