pageextension 50125 "FSN Incoming Documents Ext" extends "Incoming Documents"
{
    layout
    {
        // Add changes to page layout here
    }

    actions
    {
        addafter("Set View")
        {

            action(AdditionalDocuments)
            {
                Caption = 'Additional Documents';
                Image = AddAction;
                RunObject = Page 50000;
            }

            action(AddsDocumentsPosted)
            {
                Caption = 'Adds. Documents Posted';
                Image = PutAwayWorksheet;
                RunObject = Page 50001;
            }
        }
    }

    var
        myInt: Integer;
}