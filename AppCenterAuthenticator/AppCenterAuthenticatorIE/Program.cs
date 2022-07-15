using System;
using System.Windows.Forms;
using System.Text.RegularExpressions;

namespace AppCenterAuthenticatorIE
{
    internal class Program
    {
        private static bool Completed = false;

        [STAThread]
        static void Main(string[] args)
        {
            var web = new WebBrowser();

            web.Navigating += Web_Navigating;

            var form = new Form
            {
                AutoSize     = true,
                AutoSizeMode = AutoSizeMode.GrowOnly
            };

            form.Controls.Add(web);
            form.Controls[0].Dock = DockStyle.Fill;

            form.Show();

            web.Navigate($"{Properties.Settings.Default.AuthAddressPrefix}{Properties.Settings.Default.ClientID}{Properties.Settings.Default.AuthAddressSuffix}");

            while (!Completed)
                Application.DoEvents();
        }

        private static void Web_Navigating(object sender, WebBrowserNavigatingEventArgs e)
        {
            if (e.Url.ToString().Contains(Properties.Settings.Default.RedirectAddress))
            {
                e.Cancel = true;

                Console.WriteLine(Regex.Replace(e.Url.ToString(), "(.*code=)|(&.*)", ""));

                Completed = true;
            }
        }
    }
}
