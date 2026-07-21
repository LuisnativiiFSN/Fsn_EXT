dotnet
{
    assembly("mscorlib")
    {
        Version = '2.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Text.StringBuilder"; "StringBuilder")
        {
        }

        type("System.IO.StreamWriter"; "StreamWriter")
        {
        }

        type("System.IO.Stream"; "Stream")
        {
        }

        type("System.Text.Encoding"; "Encoding")
        {
        }
    }

    assembly("System")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Uri"; "Uri")
        {
        }

        type("System.Net.HttpWebRequest"; "HttpWebRequest")
        {
        }

        type("System.Net.HttpWebResponse"; "HttpWebResponse")
        {
        }

        type("System.Net.CredentialCache"; "CredentialCache")
        {
        }
    }

    assembly("System.Xml")
    {
        Version = '4.0.0.0';
        Culture = 'neutral';
        PublicKeyToken = 'b77a5c561934e089';

        type("System.Xml.XmlTextReader"; "XmlTextReader")
        {
        }

        type("System.Xml.XmlElement"; "XmlElement")
        {
        }
    }

}
