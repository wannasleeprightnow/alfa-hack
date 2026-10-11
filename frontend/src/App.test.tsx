import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it } from 'vitest'

import { App } from './App'

describe('App', () => {
  it('renders the Vite starter and its working counter', async () => {
    const user = userEvent.setup()
    render(<App />)

    expect(screen.getByRole('heading', { name: 'Vite + React' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'count is 0' })).toBeInTheDocument()

    await user.click(screen.getByRole('button', { name: 'count is 0' }))

    expect(screen.getByRole('button', { name: 'count is 1' })).toBeInTheDocument()
  })
})
