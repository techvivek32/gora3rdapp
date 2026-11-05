import { redirect } from 'next/navigation';

/**
 * The wording moved into the Website module, where it sits beside the hero
 * picture and the service cities instead of being a nav item of its own.
 *
 * The route stays so a bookmark, a link in a handover note or an old tab
 * still lands on the form rather than a 404.
 */
export default function WebsiteTextPage() {
  redirect('/website?tab=text');
}
