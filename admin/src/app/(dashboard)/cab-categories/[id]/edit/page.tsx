'use client';

import { use } from 'react';
import CabCategoryForm from '../../CabCategoryForm';

export default function EditCabCategoryPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return <CabCategoryForm categoryId={id} />;
}
